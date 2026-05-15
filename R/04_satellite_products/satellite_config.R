# =============================================================================
# Satellite Products — Configuration
#
# All tunable parameters for the WP6 satellite pipeline live here. Every
# downstream script (`satellite_ingest.R`, `satellite_extract.R`,
# `satellite_composite.R`, `satellite_summary.R`, `plot_satellite_climatology.R`)
# sources this file at its top.
#
# Locked decisions (see Context/satellite/wp6_session_brief.md):
#   - Chl source: OC-CCI v6 daily 4 km on NEFSC ERDDAP
#   - SST source: NOAA OISST 0.25 deg gap-filled daily (dataset ID confirmed
#     at Session C start; current best guess documented below)
#   - Temporal grid: daily ingest, 8-day composites on MODIS DOY 1, 9, 17, ...
#   - Four independent geography sets: CINAR, EcoMon, CPO, station buffers
#   - Sparse-window placeholder threshold: n_min = 22 valid pixels
#
# Download strategy (Session A finding):
#   NEFSC ERDDAP sits behind an Akamai CDN with a ~240 s response-time cap.
#   Full-GoM requests (April alone OK at 150 s; 3+ months FAIL at 240 s) are
#   not viable. We switch to PER-GEOGRAPHY-SET UNION BBOXES — one griddap
#   request per (variable, year, geography_set) — and cache to
#   data/satellite/raw/{geography_set}_{variable}_{year}.nc.
#
#   In Session A only the `stations` set is wired up; CINAR/CPO bboxes are
#   filled in at Session B when WP1 polygon sf objects are loaded. EcoMon
#   is deferred (its union bbox exceeds the GoM bbox and would still need
#   monthly chunking).
#
# Note on UTM projection for the station buffer (5 km radius):
#   Session brief specifies EPSG:32619 (WGS84 / UTM Zone 19N). work_packages.md
#   mentions EPSG:26919 (NAD83 / UTM Zone 19N). For a 5 km buffer in the
#   western Gulf of Maine the horizontal difference between datums is sub-metre.
#   Following the session brief.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})

satellite_config <- list(

  # ---------------------------------------------------------------------------
  # ERDDAP endpoints and dataset IDs
  # ---------------------------------------------------------------------------
  chlor_a = list(
    erddap_url = "https://comet.nefsc.noaa.gov/erddap",
    dataset_id = "occci_v6_daily_4km",
    field      = "chlor_a",
    units      = "mg m^-3",
    year_start = 1997,
    year_end   = 2025,              # bump as new years become available
    # Block-average the daily raster before extraction to mitigate spatial
    # cloud bias inside large polygons (Session C). fact = 3 coarsens 4 km
    # OC-CCI pixels into ~12 km blocks (mean of valid 4 km pixels in each
    # 3x3 footprint; all-NA blocks drop out). Apply uniformly to all polygons.
    block_aggregate_fact = 3L,
    # Sparse-window threshold for this variable. 22 = ~3,168 km^2 of valid
    # 12 km blocks per window. Right size for CINAR/CPO polygons.
    n_min = 22L
  ),

  # OISST dataset confirmed via verify_session_c.R (Session 16, 2026-05-14):
  #   Server          : https://coastwatch.pfeg.noaa.gov/erddap
  #   Dataset ID      : ncdcOisst21Agg_LonPM180
  #   Time coverage   : 1981-09-01 -> present (rolling), daily
  #   Spatial grid    : 0.25 deg global; lon -179.875..179.875 (Pacific-PM180)
  #   Variables       : anom, err, ice, sst (all float)
  #   Field used      : sst (standard_name = sea_surface_temperature)
  #   Units           : degree_C  (NOT 'degC' — the ERDDAP attribute string is
  #                     'degree_C'; the dataset is in degrees Celsius)
  #   Valid range     : [-3.0, 45.0]
  #   _FillValue      : -9.99
  #   Required dims   : time, zlev (must specify even though single-valued), lat, lon
  sst = list(
    erddap_url = "https://coastwatch.pfeg.noaa.gov/erddap",
    dataset_id = "ncdcOisst21Agg_LonPM180",
    field      = "sst",
    units      = "degree_C",
    year_start = 1981,
    year_end   = 2025,
    # OISST is already ~28 km (0.25 deg) — no coarsening needed.
    block_aggregate_fact = 1L,
    # OISST 2.1 carries a single-value zlev (depth) dimension; rerddap requires
    # an explicit range. zlev = 0 (surface).
    extra_dims = list(zlev = c(0, 0)),
    # Sparse-window threshold for this variable. Area-proportional to chl's
    # n_min = 22 at 12 km blocks: 22 * (12/28)^2 = 4.0, rounded up to 5 for
    # a little conservatism. n_min = 5 OISST pixels ~= 3,900 km^2 of valid
    # coverage. Clears all CINAR + EM_* polygons; SBNMS still sparse on the
    # raw threshold (handled by per-polygon override below).
    n_min = 5L
  ),

  # ---------------------------------------------------------------------------
  # Pad (degrees) added around each polygon's bbox before the ERDDAP request,
  # so polygon edge pixels are not lost to grid alignment. Must be large
  # enough that the resulting request bbox is guaranteed to span at least one
  # pixel boundary in each dimension for the *coarsest* expected variable —
  # otherwise the returned NetCDF can be 1 cell tall (or wide) and terra::rast
  # builds a degenerate raster that exact_extract finds zero overlap with.
  #
  # OISST 0.25° is the coarsest variable. A 5 km station buffer (~0.045° lat)
  # placed mid-pixel needs pad >= ~0.08° to cross the nearest pixel boundary.
  # We use 0.15° (more than half a pixel) for safety. Chl at 4 km is unaffected
  # by the larger pad except for ~3-4 extra pixels per side in the request.
  #
  # History: was 0.05° through Session E. Bumped to 0.15° at the end of
  # Session E follow-up after WBTS sst returned a 1-lat-row NetCDF that
  # produced all-NA polygon means.
  # ---------------------------------------------------------------------------
  bbox_pad_deg = 0.15,

  # ---------------------------------------------------------------------------
  # WBTS / CMTS station coordinates and buffer radius
  #
  # Buffer reduced from 7.5 km to 5 km during Session A: a 7.5 km buffer
  # intersected land along the western Maine coast at one or both stations.
  # 5 km keeps the polygon offshore while still covering ~5 OC-CCI pixels
  # for stable polygon-mean values (area ~pi*5^2 = ~78.5 km^2).
  # ---------------------------------------------------------------------------
  stations = list(
    WBTS = list(lon = -68.321, lat = 42.87),
    CMTS = list(lon = -68.481, lat = 43.75)
  ),
  station_buffer_m   = 5000,        # 5 km radius (was 7.5 km; land overlap)
  station_buffer_crs = 32619,       # WGS84 / UTM Zone 19N (see header note)

  # ---------------------------------------------------------------------------
  # 8-day window start DOYs (MODIS convention)
  # 46 windows per year; the last window covers DOY 361 through year-end
  # (5 days in non-leap years, 6 in leap years).
  # ---------------------------------------------------------------------------
  window_start_doy = seq(1L, 361L, by = 8L),
  n_windows        = 46L,

  # ---------------------------------------------------------------------------
  # Sparse-window placeholder threshold — GLOBAL DEFAULT
  #
  # Composite windows with fewer than `n_min` valid pixels are retained in
  # the summary with sparse = TRUE; the plotting layer renders these as a
  # placeholder rather than plotting a value.
  #
  # Lookup hierarchy (most specific wins):
  #   1. `geography_sets[[set]]$polygon_n_min[[polygon_id]][[variable]]`
  #   2. `config[[variable]]$n_min`  (per-variable; chl = 22, sst = 5)
  #   3. `config$n_min`              (global default, this entry)
  #
  # See `.satellite_n_min()` helper below for the lookup implementation.
  # ---------------------------------------------------------------------------
  n_min = 22L,

  # ---------------------------------------------------------------------------
  # Output paths (relative to repo root; .Rproj sets working directory)
  # ---------------------------------------------------------------------------
  paths = list(
    raw_dir      = file.path("data", "satellite", "raw"),
    summary_dir  = file.path("summaries", "satellite"),
    summary_csv  = file.path("summaries", "satellite", "satellite_summary.csv"),
    # Daily polygon-mean CSV — preserves the per polygon-day extract output
    # alongside the 8-day composite summary. Used by downstream GAM workflows
    # (e.g. CT's wbts_chl_analysis.R) that operate on daily polygon-means.
    daily_csv    = file.path("summaries", "satellite", "satellite_daily.csv"),
    plot_dir     = file.path("plots", "satellite")
  )
)

# Ensure output directories exist
for (p in c(satellite_config$paths$raw_dir,
            satellite_config$paths$summary_dir,
            satellite_config$paths$plot_dir)) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

# -----------------------------------------------------------------------------
# Station buffer sf — build at config load time.
#
# Method: project lon/lat points to UTM Zone 19N (metric), buffer by 5000 m,
# reproject back to WGS84 for ERDDAP queries and raster extraction.
# -----------------------------------------------------------------------------
satellite_config$station_buffers_sf <- local({
  stn_df <- data.frame(
    polygon_id = names(satellite_config$stations),
    lon        = vapply(satellite_config$stations, `[[`, numeric(1), "lon"),
    lat        = vapply(satellite_config$stations, `[[`, numeric(1), "lat"),
    stringsAsFactors = FALSE
  )
  st_as_sf(stn_df, coords = c("lon", "lat"), crs = 4326) |>
    st_transform(satellite_config$station_buffer_crs) |>
    st_buffer(satellite_config$station_buffer_m) |>
    st_transform(4326)
})

# -----------------------------------------------------------------------------
# Geography set registry
#
# Each entry has:
#   sf   — the sf object holding that set's polygons (NULL if not yet wired)
#   bbox — list(lon_min, lon_max, lat_min, lat_max), padded by bbox_pad_deg
#
# Session A: only `stations` is populated. CINAR and CPO are stubbed with
# NULL bbox and a TODO note — Session B will load WP1 polygons and fill these
# in. EcoMon is deferred entirely (see header note).
# -----------------------------------------------------------------------------
.bbox_from_sf <- function(sf_obj, pad) {
  bb <- sf::st_bbox(sf_obj)
  list(
    lon_min = unname(bb["xmin"]) - pad,
    lon_max = unname(bb["xmax"]) + pad,
    lat_min = unname(bb["ymin"]) - pad,
    lat_max = unname(bb["ymax"]) + pad
  )
}

# Load CINAR + CPO polygon sf objects via the dedicated loader (decoupled
# from the procedural Data_layer_Polygons.R). EcoMon stays deferred — see
# work_packages.md WP6 open items.
source(file.path("R", "04_satellite_products", "load_geography_sets.R"))

local({
  cinar_sf <- load_cinar_polygons()
  cpo_sf   <- load_cpo_polygons()

  satellite_config$geography_sets <<- list(
    stations = list(
      sf   = satellite_config$station_buffers_sf,
      bbox = .bbox_from_sf(satellite_config$station_buffers_sf,
                           satellite_config$bbox_pad_deg),
      # Override the variable-level block_aggregate_fact: stations use a
      # simple polygon mean of native pixels regardless of variable. The
      # cloud-bias-mitigation rationale for 12 km blocks does not apply at
      # 5 km buffer scale, and 12 km blocks would alias to 1-2 blocks per
      # buffer. Set 2026-05-14 (Session C). NULL = use vcfg default.
      block_aggregate_fact = 1L,
      # Per-polygon n_min overrides: render station data even though the
      # 5 km buffer can never clear the polygon-scale n_min thresholds.
      # For chl: a 5 km buffer on 4 km grid has ~5-14 pixels per clear day.
      # For sst: 5 km buffer fits inside a single 0.25 deg OISST pixel.
      # Treat like SBNMS — accept the few-pixel reading rather than always
      # render a placeholder. Set 2026-05-15 (Session E follow-up).
      polygon_n_min = list(
        WBTS = list(chlor_a = 1L, sst = 1L),
        CMTS = list(chlor_a = 1L, sst = 1L)
      )
    ),
    cinar = list(
      sf   = cinar_sf,
      bbox = .bbox_from_sf(cinar_sf, satellite_config$bbox_pad_deg)
      # block_aggregate_fact unset -> use vcfg default (3 for chl, 1 for sst)
    ),
    cpo = list(
      sf   = cpo_sf,
      bbox = .bbox_from_sf(cpo_sf, satellite_config$bbox_pad_deg),
      # SBNMS (~2,200 km^2) is small relative to the OISST 0.25 deg grid
      # (~3 pixels of coverage). Treat its SST series like a station's:
      # accept that the polygon mean is essentially a few-pixel reading and
      # don't suppress real data with a sparse placeholder. n_min = 1 lets
      # any valid-pixel reading render.
      polygon_n_min = list(
        SBNMS = list(sst = 1L)
      )
    )
    # ecomon: deliberately omitted; union bbox spans most of NE shelf and
    # would still need monthly chunking under the per-set strategy. Add a
    # loader and wire here when Session C/D reintroduces it.
  )
})

# -----------------------------------------------------------------------------
# Helper: bbox lookup with friendly error
# -----------------------------------------------------------------------------
satellite_bbox <- function(geography_set, config = satellite_config) {
  if (!geography_set %in% names(config$geography_sets)) {
    stop("Unknown geography_set: ", geography_set,
         ". Known: ", paste(names(config$geography_sets), collapse = ", "))
  }
  bb <- config$geography_sets[[geography_set]]$bbox
  if (is.null(bb)) {
    stop("geography_set '", geography_set, "' is not yet wired up ",
         "(bbox = NULL). See TODOs in satellite_config.R.")
  }
  bb
}


# -----------------------------------------------------------------------------
# Helper: per-row n_min lookup
#
# Returns the sparse-window threshold for a single (geography_set, polygon_id,
# variable) triple, walking the hierarchy:
#   1. polygon-specific override in geography_sets[[set]]$polygon_n_min
#   2. per-variable override in config[[variable]]$n_min
#   3. global default config$n_min
# -----------------------------------------------------------------------------
.satellite_n_min <- function(geography_set, polygon_id, variable,
                             config = satellite_config) {
  set_entry <- config$geography_sets[[geography_set]]
  if (!is.null(set_entry$polygon_n_min)) {
    poly_overrides <- set_entry$polygon_n_min[[polygon_id]]
    if (!is.null(poly_overrides) && !is.null(poly_overrides[[variable]])) {
      return(as.integer(poly_overrides[[variable]]))
    }
  }
  vcfg <- config[[variable]]
  if (!is.null(vcfg) && !is.null(vcfg$n_min)) {
    return(as.integer(vcfg$n_min))
  }
  as.integer(config$n_min)
}


# -----------------------------------------------------------------------------
# Vectorized version of `.satellite_n_min` for use inside composite_to_8day.
# Returns an integer vector aligned with the input vectors.
# -----------------------------------------------------------------------------
.satellite_n_min_vec <- function(geography_set, polygon_id, variable,
                                 config = satellite_config) {
  n <- length(geography_set)
  out <- integer(n)
  # Vectorize by unique key for speed on the ~50k-row composite frame.
  key <- paste(geography_set, polygon_id, variable, sep = "\037")
  ukey <- unique(key)
  for (k in ukey) {
    idx <- which(key == k)
    parts <- strsplit(k, "\037", fixed = TRUE)[[1L]]
    out[idx] <- .satellite_n_min(parts[1], parts[2], parts[3], config)
  }
  out
}
