# =============================================================================
# Satellite Products — Ingest Layer
#
# Downloads satellite data from ERDDAP at PER-POLYGON granularity and caches
# one NetCDF per polygon-year-variable to
#   data/satellite/raw/{geography_set}/{polygon_id}_{variable}_{year}.nc
#
# Why per-polygon: NEFSC ERDDAP sits behind an Akamai CDN with a hard ~240 s
# response-time cap. Per-geography-set union bboxes worked for the small
# `stations` set but failed for CINAR (251 s, bbox ~13.7° × 6.9°). Per-polygon
# requests are reliable: each polygon's bbox is ~1 deg² or smaller, well under
# the timeout. Total request count is higher but each request is small.
#
# The user-facing API does not change: `ingest_satellite(variable, year,
# geography_set)` still ingests an entire set in one call. Internally it
# iterates over polygons.
#
# Downloads are atomic (copied to `.tmp` then renamed) and resumable (existing
# per-polygon NetCDFs larger than the min size are skipped). The `polygon_ids`
# argument lets callers ingest a subset of polygons — useful for verification
# and for resuming a partial run.
# =============================================================================

suppressPackageStartupMessages({
  library(rerddap)
  library(sf)
  library(dplyr)
  library(lubridate)
})

if (!exists("satellite_config")) {
  source(file.path("R", "04_satellite_products", "satellite_config.R"))
}

satellite_min_nc_bytes <- 10 * 1024L


#' Cache path for a single polygon-year-variable NetCDF
satellite_polygon_path <- function(geography_set, polygon_id, variable, year,
                                   config = satellite_config) {
  file.path(config$paths$raw_dir,
            geography_set,
            sprintf("%s_%s_%d.nc", polygon_id, variable, year))
}


#' Download one polygon-year of satellite data from ERDDAP
#'
#' @return Path to cached NetCDF on success, NULL on failure.
.ingest_one_polygon <- function(variable, year, geography_set,
                                polygon_id, poly_sf,
                                config, vcfg, info_obj,
                                overwrite) {
  target <- satellite_polygon_path(geography_set, polygon_id,
                                   variable, year, config)
  set_dir <- dirname(target)
  if (!dir.exists(set_dir)) dir.create(set_dir, recursive = TRUE)

  if (!overwrite && file.exists(target) &&
      file.info(target)$size >= satellite_min_nc_bytes) {
    message(sprintf("[ingest]   skip %s/%s/%s %d (cached)",
                    geography_set, polygon_id, variable, year))
    return(target)
  }

  bb_raw <- sf::st_bbox(poly_sf)
  pad    <- config$bbox_pad_deg
  lat_range <- c(unname(bb_raw["ymin"]) - pad, unname(bb_raw["ymax"]) + pad)
  lon_range <- c(unname(bb_raw["xmin"]) - pad, unname(bb_raw["xmax"]) + pad)

  start_date <- sprintf("%d-01-01", year)
  end_date   <- sprintf("%d-12-31", year)

  message(sprintf("[ingest]   fetch %s/%s/%s %d  bbox lon[%.3f,%.3f] lat[%.3f,%.3f]",
                  geography_set, polygon_id, variable, year,
                  lon_range[1], lon_range[2], lat_range[1], lat_range[2]))

  griddap_args <- list(
    info_obj,
    time      = c(start_date, end_date),
    latitude  = lat_range,
    longitude = lon_range,
    fields    = vcfg$field,
    url       = vcfg$erddap_url
  )
  # Some datasets (e.g. OISST) require an explicit `zlev` constraint even when
  # the dimension has a single value. Variable config can pass these through.
  if (!is.null(vcfg$extra_dims)) {
    griddap_args <- c(griddap_args, vcfg$extra_dims)
  }

  result <- tryCatch({
    dat <- do.call(rerddap::griddap, griddap_args)

    src_path <- attr(dat, "path")
    if (is.null(src_path) || !file.exists(src_path)) {
      src_path <- tryCatch(dat$summary$filename, error = function(e) NULL)
    }
    if (is.null(src_path) || !file.exists(src_path)) {
      stop("Could not locate rerddap cache file")
    }

    tmp_path <- paste0(target, ".tmp")
    ok <- file.copy(src_path, tmp_path, overwrite = TRUE)
    if (!ok) stop("file.copy failed: ", src_path, " -> ", tmp_path)
    # file.rename can return FALSE silently on Windows when antivirus holds
    # a read lock on the .tmp file. Retry once after a short pause; abort if
    # still failing so the polygon shows in the failure log (versus silently
    # missing and triggering a re-download on next resume).
    ok_rename <- file.rename(tmp_path, target)
    if (!ok_rename) {
      warning(sprintf("[ingest]   file.rename returned FALSE for %s -> %s; retrying in 2 s",
                      tmp_path, target))
      Sys.sleep(2)
      ok_rename <- file.rename(tmp_path, target)
      if (!ok_rename) {
        stop(sprintf("file.rename failed twice (likely AV/file lock): %s -> %s",
                     tmp_path, target))
      }
    }

    target

  }, error = function(e) {
    warning(sprintf("[ingest]   FAILED %s/%s/%s %d: %s",
                    geography_set, polygon_id, variable, year,
                    conditionMessage(e)))
    tmp_path <- paste0(target, ".tmp")
    if (file.exists(tmp_path)) file.remove(tmp_path)
    NULL
  })

  Sys.sleep(0.3)
  result
}


#' Ingest one (variable, year) for a whole geography set, polygon-by-polygon
#'
#' @param variable      Character. "chlor_a" or "sst".
#' @param year          Integer.
#' @param geography_set Character. A key in `config$geography_sets`.
#' @param config        List. Defaults to satellite_config.
#' @param overwrite     Logical. Re-download even if cache is present.
#' @param polygon_ids   Optional character vector of polygon_id values to limit
#'   the ingest to (matched against `geography_sets[[set]]$sf$polygon_id`).
#'   NULL = ingest all polygons in the set.
#'
#' @return Invisibly returns a named list mapping polygon_id -> cached path
#'   (or NULL for failures).
ingest_satellite <- function(variable, year, geography_set,
                             config = satellite_config,
                             overwrite = FALSE,
                             polygon_ids = NULL) {

  if (!variable %in% names(config) ||
      is.null(config[[variable]]$dataset_id)) {
    stop("Unknown satellite variable: ", variable)
  }
  vcfg <- config[[variable]]

  set_entry <- config$geography_sets[[geography_set]]
  if (is.null(set_entry) || is.null(set_entry$sf)) {
    stop("geography_set '", geography_set, "' is not wired up.")
  }
  polys_sf <- set_entry$sf
  if (!is.null(polygon_ids)) {
    keep <- polys_sf$polygon_id %in% polygon_ids
    if (!any(keep)) {
      stop("None of the requested polygon_ids found in '", geography_set,
           "': ", paste(polygon_ids, collapse = ", "))
    }
    polys_sf <- polys_sf[keep, ]
  }

  info_obj <- rerddap::info(vcfg$dataset_id, url = vcfg$erddap_url)

  message(sprintf("[ingest] %s/%s %d — %d polygon(s)",
                  geography_set, variable, year, nrow(polys_sf)))

  paths <- vector("list", nrow(polys_sf))
  names(paths) <- as.character(polys_sf$polygon_id)
  for (i in seq_len(nrow(polys_sf))) {
    pid <- as.character(polys_sf$polygon_id[i])
    paths[[pid]] <- .ingest_one_polygon(
      variable, year, geography_set,
      polygon_id = pid,
      poly_sf    = polys_sf[i, ],
      config     = config,
      vcfg       = vcfg,
      info_obj   = info_obj,
      overwrite  = overwrite
    )
  }

  invisible(paths)
}
