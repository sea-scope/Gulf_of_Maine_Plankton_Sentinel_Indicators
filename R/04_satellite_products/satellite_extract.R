# =============================================================================
# Satellite Products — Polygon Extraction Layer
#
# Loads per-polygon NetCDFs cached by satellite_ingest.R, optionally block-
# averages the daily raster, extracts fractional-pixel-area-weighted statistics
# per polygon * day, and returns a long-format data frame ready for compositing.
#
# Session C methodology (locked):
#   1. Block-average each daily layer BEFORE exact_extract using
#      `terra::aggregate(r, fact = c(B, B), fun = "mean", na.rm = TRUE)` where
#      B is `config[[variable]]$block_aggregate_fact` (3 for OC-CCI 4 km -> 12
#      km; 1 for OISST 0.25 deg, no-op). This gives each ~12 km sub-area inside
#      the polygon equal weight regardless of cloud frequency in that sub-area.
#   2. Return per polygon-day SUFFICIENT STATISTICS so the composite step can
#      pool within-day spatial variability and between-day temporal variability
#      into a single 8-day pixel SD. Stats are computed on the *coarsened*
#      raster using `coverage_fraction` as the per-block weight.
#
# Cache layout (per-polygon, set in satellite_ingest.R):
#   data/satellite/raw/{geography_set}/{polygon_id}_{variable}_{year}.nc
#
# One call per (variable, year, geography_set). The orchestrator
# (run_satellite.R) loops over combinations.
# =============================================================================

suppressPackageStartupMessages({
  library(terra)
  library(exactextractr)
  library(sf)
  library(dplyr)
  library(ncdf4)
})

if (!exists("satellite_config")) {
  source(file.path("R", "04_satellite_products", "satellite_config.R"))
}


# -----------------------------------------------------------------------------
# Read the time axis of a NetCDF as a vector of Dates.
# Robust to a couple of common epoch-string formats.
# -----------------------------------------------------------------------------
.nc_time_as_dates <- function(nc_path) {
  nc <- ncdf4::nc_open(nc_path)
  on.exit(ncdf4::nc_close(nc), add = TRUE)
  t_raw   <- ncdf4::ncvar_get(nc, "time")
  # Some NetCDFs (notably OISST with a singleton zlev) cause ncvar_get to
  # return a matrix/array with degenerate dimensions. Flatten to a plain
  # numeric vector so the downstream arithmetic and as.Date() produce a
  # 1-D Date vector and not a matrix.
  t_raw <- as.numeric(t_raw)
  t_units <- ncdf4::ncatt_get(nc, "time", "units")$value

  unit_match <- regmatches(t_units,
                           regexec("^([a-zA-Z]+)\\s+since\\s+(.+)$", t_units))[[1]]
  if (length(unit_match) < 3L) {
    stop("Unrecognized time units string in ", nc_path, ": ", t_units)
  }
  unit_word <- tolower(unit_match[2])
  epoch_str <- unit_match[3]

  scale_sec <- switch(unit_word,
                      seconds = 1,
                      second  = 1,
                      minutes = 60,
                      minute  = 60,
                      hours   = 3600,
                      hour    = 3600,
                      days    = 86400,
                      day     = 86400,
                      stop("Unsupported time unit '", unit_word, "' in ", nc_path))

  epoch <- as.POSIXct(epoch_str, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(epoch)) epoch <- as.POSIXct(epoch_str, tz = "UTC")
  if (is.na(epoch)) epoch <- as.POSIXct(epoch_str, tz = "UTC", format = "%Y-%m-%d")
  if (is.na(epoch)) {
    stop("Could not parse epoch '", epoch_str, "' in ", nc_path)
  }
  out <- as.Date(epoch + t_raw * scale_sec)
  # Guard: if anything earlier produced an array-shaped Date, drop dim so we
  # return a clean 1-D Date vector. Otherwise downstream data.frame() can
  # silently wrap it as a matrix column and break readr::write_csv.
  if (!is.null(dim(out))) dim(out) <- NULL
  out
}


# -----------------------------------------------------------------------------
# Extract per-polygon * date sufficient statistics from one NetCDF.
#
# block_fact: integer aggregation factor applied with terra::aggregate before
#   exact_extract. block_fact = 1 (or NULL) skips the aggregation step
#   (OISST is already ~28 km).
# -----------------------------------------------------------------------------
.extract_one_polygon <- function(nc_path, poly_sf, geography_set,
                                 polygon_id, variable, block_fact) {

  r <- terra::rast(nc_path)
  layer_dates <- .nc_time_as_dates(nc_path)
  if (terra::nlyr(r) != length(layer_dates)) {
    stop("Layer count mismatch in ", nc_path)
  }

  # Block-average the daily raster to ~12 km blocks (chl) or pass through (SST).
  # Each block is the mean of valid native pixels in its block_fact x block_fact
  # footprint; blocks where all native pixels are NA drop out (na.rm = TRUE).
  # Apply uniformly to all polygons.
  if (!is.null(block_fact) && block_fact > 1L) {
    r <- terra::aggregate(r,
                          fact   = c(block_fact, block_fact),
                          fun    = "mean",
                          na.rm  = TRUE)
  }
  names(r) <- as.character(layer_dates)

  ee <- tryCatch(
    exactextractr::exact_extract(r, poly_sf, coverage_area = FALSE,
                                 progress = FALSE),
    error = function(e) NULL
  )

  n_lyr <- length(layer_dates)
  out_mean    <- rep(NA_real_, n_lyr)
  out_sum_w   <- rep(NA_real_, n_lyr)
  out_sum_wx  <- rep(NA_real_, n_lyr)
  out_sum_wxx <- rep(NA_real_, n_lyr)
  out_n       <- rep(0L, n_lyr)

  if (!is.null(ee) && length(ee) > 0L) {
    df <- ee[[1L]]
    fracs <- df$coverage_fraction
    for (li in seq_len(n_lyr)) {
      layer_col <- names(r)[li]
      vals <- df[[layer_col]]
      ok   <- !is.na(vals) & fracs > 0
      n_valid <- sum(ok)
      out_n[li] <- as.integer(n_valid)
      if (n_valid > 0L) {
        v  <- vals[ok]
        w  <- fracs[ok]
        sw   <- sum(w)
        swx  <- sum(w * v)
        swxx <- sum(w * v * v)
        out_sum_w[li]   <- sw
        out_sum_wx[li]  <- swx
        out_sum_wxx[li] <- swxx
        out_mean[li]    <- swx / sw
      }
    }
  }

  data.frame(
    geography_set  = geography_set,
    polygon_id     = polygon_id,
    date           = layer_dates,
    variable       = variable,
    variable_mean  = out_mean,
    sum_w          = out_sum_w,
    sum_wx         = out_sum_wx,
    sum_wxx        = out_sum_wxx,
    n_valid_pixels = out_n,
    stringsAsFactors = FALSE
  )
}


#' Extract per-polygon sufficient statistics for a (variable, year, geography_set)
#'
#' Reads each polygon's NetCDF from the per-polygon cache, optionally
#' block-aggregates per `config[[variable]]$block_aggregate_fact`, runs
#' fractional-pixel-weighted `exact_extract`, and binds the rows.
#'
#' @param variable      Character. e.g. "chlor_a", "sst".
#' @param year          Integer.
#' @param geography_set Character. Key in `config$geography_sets`.
#' @param config        List. Defaults to satellite_config.
#'
#' @return Long-format data frame with one row per polygon * date and columns:
#'   geography_set, polygon_id, date, variable, variable_mean, sum_w, sum_wx,
#'   sum_wxx, n_valid_pixels. The four sufficient statistics feed
#'   `composite_to_8day()` to produce a properly pooled within-window pixel SD.
#'   Polygons with no cached NetCDF are silently skipped (a message lists which).
extract_satellite <- function(variable, year, geography_set,
                              config = satellite_config) {

  vcfg <- config[[variable]]
  if (is.null(vcfg) || is.null(vcfg$dataset_id)) {
    stop("Unknown satellite variable: ", variable)
  }

  set_entry <- config$geography_sets[[geography_set]]
  if (is.null(set_entry) || is.null(set_entry$sf)) {
    stop("geography_set '", geography_set, "' is not wired up.")
  }
  polys_sf <- set_entry$sf

  # Per-geography-set override (e.g. stations -> 1, no coarsening) wins over
  # the variable-level default (chl -> 3 for ~12 km blocks; sst -> 1).
  block_fact <- set_entry$block_aggregate_fact
  if (is.null(block_fact)) block_fact <- vcfg$block_aggregate_fact
  if (is.null(block_fact)) block_fact <- 1L

  message(sprintf("[extract] %s/%s %d — %d polygons (block_fact = %d)",
                  geography_set, variable, year, nrow(polys_sf), block_fact))

  results <- vector("list", nrow(polys_sf))
  missing_polys <- character(0)

  for (i in seq_len(nrow(polys_sf))) {
    pid <- as.character(polys_sf$polygon_id[i])
    nc_path <- satellite_polygon_path(geography_set, pid, variable, year, config)
    if (!file.exists(nc_path)) {
      missing_polys <- c(missing_polys, pid)
      next
    }
    results[[i]] <- .extract_one_polygon(
      nc_path        = nc_path,
      poly_sf        = polys_sf[i, ],
      geography_set  = geography_set,
      polygon_id     = pid,
      variable       = variable,
      block_fact     = block_fact
    )
  }

  if (length(missing_polys) > 0L) {
    message("[extract]   skipped (no cache): ",
            paste(missing_polys, collapse = ", "))
  }

  dplyr::bind_rows(results)
}
