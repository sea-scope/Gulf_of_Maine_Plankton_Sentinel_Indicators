# =============================================================================
# Satellite Products — Geography Set Loaders
#
# Builds the CINAR and CPO sf polygon objects used as extraction footprints,
# decoupled from the procedural WP1 script `Data_layer_Polygons.R` (which has
# side effects unrelated to satellite extraction).
#
# Station buffers are built inside satellite_config.R at load time and are not
# duplicated here.
#
# EcoMon is intentionally not loaded for WP6 Session A/B (see handoff). When it
# is reintroduced, add an `ecomon` loader here that reads the strata sf and
# returns the 33 strata as a single sf with polygon_id = stratum number.
#
# Polygon CSV provenance note: WP3.5 moved most pre-clipped polygon CSVs from
# `data/` to `data/spm_biomass/`, but several were left behind. This loader
# tries both locations so it works regardless of whether the move is finished.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})

sf_use_s2(FALSE)   # planar geometry, matching Data_layer_Polygons.R

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

#' Locate a polygon CSV in `data/spm_biomass/` or fall back to `data/`.
.find_poly_csv <- function(name) {
  candidates <- c(
    file.path("data", "spm_biomass", name),
    file.path("data", name)
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0L) {
    stop("Polygon CSV not found in data/spm_biomass/ or data/: ", name)
  }
  hit[[1L]]
}

#' Read a headerless lon,lat CSV into a closed-ring matrix and return an sfc.
.read_poly_sfc <- function(path) {
  df  <- read.table(path, sep = ",", header = FALSE)
  mat <- as.matrix(df[, 1:2])
  colnames(mat) <- c("lon", "lat")
  if (!isTRUE(all.equal(mat[1, ], mat[nrow(mat), ]))) {
    mat <- rbind(mat, mat[1, ])
  }
  st_sfc(st_polygon(list(mat)), crs = 4326)
}


# -----------------------------------------------------------------------------
# CINAR — 8 polygons, excluding SBNMS
#
# Polygon IDs and source CSVs mirror Data_layer_Polygons.R lines 82-97.
# SBNMS (CINAR_poly = 9) is the satellite pipeline's CPO seed, not a CINAR
# polygon for satellite purposes, so it's excluded here.
# -----------------------------------------------------------------------------
load_cinar_polygons <- function() {
  cinar_specs <- list(
    list(id = "GMB150",     csv = "poly_GMB_150.csv"),
    list(id = "JB",         csv = "poly_JB_deep.csv"),
    list(id = "GeorgesNEC", csv = "poly_GeorgesNEC.csv"),
    list(id = "BOF",        csv = "poly_BOF_latlon.csv"),
    list(id = "WSS",        csv = "poly_WSS_broad.csv"),
    list(id = "EGOM",       csv = "poly_EGOM_broad.csv"),
    list(id = "Browns",     csv = "poly_Browns_line.csv"),
    list(id = "Halifax",    csv = "poly_Halifax_line.csv")
  )

  geoms <- lapply(cinar_specs,
                  function(s) .read_poly_sfc(.find_poly_csv(s$csv))[[1L]])
  ids   <- vapply(cinar_specs, `[[`, character(1), "id")

  st_sf(
    polygon_id = ids,
    geometry   = st_sfc(geoms, crs = 4326),
    row.names  = ids
  )
}


# -----------------------------------------------------------------------------
# EcoMon strata — internal helper, used by CPO loader.
#
# Builds a 33-stratum sf from `data/spm_biomass/EMstrata_v4_coords.csv`
# (one (stratum_id, lon, lat) row per ring vertex). Caches as
# `cache/ne_strata_cache.rds`, matching the WP1 cache convention.
# -----------------------------------------------------------------------------
.load_ecomon_strata <- function() {
  cache_path <- file.path("cache", "ne_strata_cache.rds")
  if (file.exists(cache_path)) {
    return(readRDS(cache_path))
  }

  coords_file <- file.path("data", "spm_biomass", "EMstrata_v4_coords.csv")
  if (!file.exists(coords_file)) {
    stop("EMstrata_v4_coords.csv not found at ", coords_file)
  }

  coords <- read.csv(coords_file)
  strata_list <- lapply(split(coords, coords$stratum_id), function(df) {
    mat <- as.matrix(df[, c("lon", "lat")])
    if (!isTRUE(all.equal(mat[1, ], mat[nrow(mat), ]))) {
      mat <- rbind(mat, mat[1, ])
    }
    st_polygon(list(mat))
  })

  sf_obj <- st_sf(
    EcoMon_poly = as.integer(names(strata_list)),
    geometry    = st_sfc(strata_list, crs = 4326)
  )

  if (!dir.exists("cache")) dir.create("cache", recursive = TRUE)
  saveRDS(sf_obj, cache_path)
  sf_obj
}


# -----------------------------------------------------------------------------
# CPO — SBNMS + EcoMon strata 35, 36, 37, 40
#
# Returns 5 polygons in a single sf. polygon_id values: "SBNMS", "EM_35",
# "EM_36", "EM_37", "EM_40".
# -----------------------------------------------------------------------------
load_cpo_polygons <- function() {
  sbnms_geom <- .read_poly_sfc(.find_poly_csv("SBNMS.csv"))[[1L]]

  ecomon_sf <- .load_ecomon_strata()
  cpo_strata <- c(35L, 36L, 37L, 40L)
  em_subset  <- ecomon_sf[ecomon_sf$EcoMon_poly %in% cpo_strata, ]
  if (nrow(em_subset) != length(cpo_strata)) {
    missing <- setdiff(cpo_strata, em_subset$EcoMon_poly)
    stop("Missing CPO EcoMon strata: ",
         paste(missing, collapse = ", "))
  }

  em_ids   <- sprintf("EM_%02d", em_subset$EcoMon_poly)
  em_geoms <- st_geometry(em_subset)

  st_sf(
    polygon_id = c("SBNMS", em_ids),
    geometry   = st_sfc(c(list(sbnms_geom), as.list(em_geoms)), crs = 4326)
  )
}
