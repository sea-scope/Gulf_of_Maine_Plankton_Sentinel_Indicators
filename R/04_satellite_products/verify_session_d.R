# =============================================================================
# WP6 Session D — Validation Script (cache-only)
#
# Run from project root:
#   source("R/04_satellite_products/verify_session_d.R")
#
# Validates the new Session D layers (satellite_summary.R,
# plot_satellite_climatology.R, run_satellite.R) end-to-end against the
# existing Session B/C NetCDF cache. No new downloads.
#
# Expected cache contents (from Sessions A-C):
#   data/satellite/raw/stations/WBTS_chlor_a_2020.nc
#   data/satellite/raw/stations/CMTS_chlor_a_2020.nc
#   data/satellite/raw/stations/CMTS_sst_2020.nc
#   data/satellite/raw/cinar/GMB150_chlor_a_2020.nc
#
# Outputs of this script:
#   - summaries/satellite/satellite_summary.csv         (small subset)
#   - plots/satellite/stations/stations_WBTS_chlor_a_overview.png
#   - plots/satellite/stations/stations_WBTS_chlor_a_2020.png
#   - plots/satellite/stations/stations_CMTS_chlor_a_overview.png
#   - plots/satellite/stations/stations_CMTS_chlor_a_2020.png
#   - plots/satellite/stations/stations_CMTS_sst_overview.png
#   - plots/satellite/stations/stations_CMTS_sst_2020.png
#   - plots/satellite/cinar/cinar_GMB150_chlor_a_overview.png
#   - plots/satellite/cinar/cinar_GMB150_chlor_a_2020.png
#   (plus placeholder PNGs for the 7 uncached CINAR polygons)
#
# After this passes, the long ingest can be kicked off via run_satellite.R
# with the default scope (NULL filters, SKIP_INGEST = FALSE).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

source("R/04_satellite_products/satellite_config.R")
source("R/04_satellite_products/satellite_extract.R")
source("R/04_satellite_products/satellite_composite.R")
source("R/04_satellite_products/satellite_summary.R")
source("R/04_satellite_products/plot_satellite_climatology.R")


# -----------------------------------------------------------------------------
# 1) Write a small summary CSV from the existing cache
# -----------------------------------------------------------------------------
cat("\n=== Session D — write small summary + daily CSVs (cache-only) ===\n")
t0 <- Sys.time()

out_dfs <- write_satellite_summary(
  geography_sets = c("stations", "cinar"),
  variables      = c("chlor_a", "sst"),
  years          = 2020
)
summary_df <- out_dfs$summary
daily_df   <- out_dfs$daily

cat(sprintf("[verify_d] summary wall time: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat(sprintf("[verify_d] summary: %d rows (expected ~184)\n", nrow(summary_df)))
cat(sprintf("[verify_d] daily:   %d rows (expected ~ (3 chl + 1 sst) * 366 = 1464)\n",
            nrow(daily_df)))

cat("\nSummary row counts by (geography_set, polygon_id, variable):\n")
print(as.data.frame(dplyr::count(summary_df, geography_set, polygon_id, variable)))

cat("\nDaily row counts by (geography_set, polygon_id, variable):\n")
print(as.data.frame(dplyr::count(daily_df, geography_set, polygon_id, variable)))

cat("\nSparse-flag breakdown by (geography_set, variable):\n")
summary_df |>
  group_by(geography_set, variable) |>
  summarise(n_total   = n(),
            n_sparse  = sum(sparse),
            n_nonsparse = sum(!sparse),
            .groups   = "drop") |>
  print()


# -----------------------------------------------------------------------------
# 2) Generate plots from the small summary
# -----------------------------------------------------------------------------
cat("\n=== Session D — generate plots from small summary ===\n")
t0 <- Sys.time()

plot_log <- plot_satellite_climatology(
  geography_sets = c("stations", "cinar"),
  variables      = c("chlor_a", "sst"),
  years          = 2020
)

cat(sprintf("[verify_d] plot wall time: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat(sprintf("[verify_d] %d PNGs written (overviews + per-year for each combo)\n",
            nrow(plot_log)))

cat("\nPNG paths written:\n")
print(plot_log)

cat("\n=== Session D verification complete ===\n")
cat("Inspect a couple of the PNGs visually before kicking off the long ingest.\n")
cat("Recommended spot-checks:\n")
cat("  - plots/satellite/cinar/cinar_GMB150_chlor_a_2020.png  (focus year on top of single-year clim)\n")
cat("  - plots/satellite/stations/stations_CMTS_chlor_a_overview.png  (all rows likely sparse-flagged)\n")
