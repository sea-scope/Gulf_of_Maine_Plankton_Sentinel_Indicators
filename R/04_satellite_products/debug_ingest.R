# =============================================================================
# WP6 Session A — Ingest debug helper
#
# Progressively scales up ERDDAP griddap requests to isolate whether the
# Akamai CDN error on the full GoM bbox/year is transient or a real
# request-size ceiling.
#
# Run from project root with:
#   source("R/04_satellite_products/debug_ingest.R")
# =============================================================================

suppressPackageStartupMessages({
  library(rerddap)
})

source("R/04_satellite_products/satellite_config.R")

url <- satellite_config$chlor_a$erddap_url
did <- satellite_config$chlor_a$dataset_id
fld <- satellite_config$chlor_a$field
# NOTE: The Session A top-level `satellite_config$bbox` (full GoM box) was
# removed in Session B when ingest switched to per-geography-set / per-polygon
# bboxes. For sizing the request-scaling tests below we use the stations set's
# union bbox padded the same way the production ingest does. The original
# GoM-wide bbox values were lon -71.5..-64.5, lat 40.0..45.5 — substitute by
# hand if you want to reproduce the full-GoM CDN-timeout test.
bx  <- satellite_config$geography_sets$stations$bbox

info_obj <- info(did, url = url)

run_test <- function(label, time_range, lat_range, lon_range) {
  cat(sprintf("\n--- %s ---\n", label))
  cat(sprintf("  time: %s to %s\n", time_range[1], time_range[2]))
  cat(sprintf("  lat:  %.2f to %.2f\n", lat_range[1], lat_range[2]))
  cat(sprintf("  lon:  %.2f to %.2f\n", lon_range[1], lon_range[2]))
  t0 <- Sys.time()
  res <- tryCatch({
    dat <- griddap(
      info_obj,
      time      = time_range,
      latitude  = lat_range,
      longitude = lon_range,
      fields    = fld,
      url       = url
    )
    path <- attr(dat, "path")
    sz <- if (!is.null(path) && file.exists(path)) file.info(path)$size else NA
    list(ok = TRUE, rows = nrow(dat$data), size_mb = sz / 1024^2)
  }, error = function(e) {
    list(ok = FALSE, msg = conditionMessage(e))
  })
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (res$ok) {
    cat(sprintf("  OK   (%.1fs, %d rows, %.1f MB)\n",
                dt, res$rows, res$size_mb))
  } else {
    cat(sprintf("  FAIL (%.1fs) — %s\n", dt, res$msg))
  }
  Sys.sleep(1)
  invisible(res)
}

cat("\n========================================")
cat("\n  ERDDAP request size sweep — chlor_a")
cat("\n========================================")

# Test 1: tiny — single pixel-ish, single day. Smoke test for the call.
run_test(
  "1. Tiny: 1 day, ~0.1 deg around CMTS",
  time_range = c("2020-04-15", "2020-04-15"),
  lat_range  = c(43.70, 43.80),
  lon_range  = c(-68.55, -68.45)
)

# Test 2: small bbox, full year (mirrors reference script style)
run_test(
  "2. Reference-style: 1 yr, 0.1 deg around CMTS",
  time_range = c("2020-01-01", "2020-12-31"),
  lat_range  = c(43.70, 43.80),
  lon_range  = c(-68.55, -68.45)
)

# Test 3: full GoM bbox, one month
run_test(
  "3. Full GoM bbox, 1 month (April 2020)",
  time_range = c("2020-04-01", "2020-04-30"),
  lat_range  = c(bx$lat_min, bx$lat_max),
  lon_range  = c(bx$lon_min, bx$lon_max)
)

# Test 4: full GoM bbox, one quarter
run_test(
  "4. Full GoM bbox, Q2 2020 (3 months)",
  time_range = c("2020-04-01", "2020-06-30"),
  lat_range  = c(bx$lat_min, bx$lat_max),
  lon_range  = c(bx$lon_min, bx$lon_max)
)

# Test 5: full GoM bbox, full year (the failing case)
run_test(
  "5. Full GoM bbox, full year 2020 (failing case)",
  time_range = c("2020-01-01", "2020-12-31"),
  lat_range  = c(bx$lat_min, bx$lat_max),
  lon_range  = c(bx$lon_min, bx$lon_max)
)

cat("\n=== Debug sweep complete ===\n")
