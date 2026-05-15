# =============================================================================
# WP6 Session B — Verification Script (per-polygon ingest)
#
# Run from project root:
#   source("R/04_satellite_products/verify_session_b.R")
#
# Steps:
#   1. Print geography-set bboxes (info only — actual ingest is per-polygon).
#   2. Stations: ingest WBTS + CMTS for chlor_a 2020 (2 small per-polygon
#      requests). Extract + composite. Plot the 8-day seasonal cycle.
#   3. CINAR/GMB150 only: ingest one polygon for chlor_a 2020. Extract +
#      composite. Plot the seasonal cycle — expect spring bloom DOY 80-140.
#
# Note: the Session A cache file `data/satellite/raw/stations_chlor_a_2020.nc`
# (monolithic, set-level) is no longer used; delete it if you want to tidy up.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
})

source("R/04_satellite_products/satellite_config.R")
source("R/04_satellite_products/satellite_ingest.R")
source("R/04_satellite_products/satellite_extract.R")
source("R/04_satellite_products/satellite_composite.R")


# -----------------------------------------------------------------------------
# 1) Geography-set bboxes (informational)
# -----------------------------------------------------------------------------
cat("\n=== Geography-set union bboxes (informational; ingest is per-polygon) ===\n")
for (nm in names(satellite_config$geography_sets)) {
  entry <- satellite_config$geography_sets[[nm]]
  bb <- entry$bbox
  cat(sprintf(
    "  %-9s: lon [%7.2f, %7.2f]  lat [%6.2f, %6.2f]  (%4.1f x %4.1f deg, %d polys)\n",
    nm, bb$lon_min, bb$lon_max, bb$lat_min, bb$lat_max,
    bb$lon_max - bb$lon_min, bb$lat_max - bb$lat_min,
    nrow(entry$sf)
  ))
}


# -----------------------------------------------------------------------------
# 2) Stations: ingest both buffers, then extract + composite
# -----------------------------------------------------------------------------
cat("\n=== Stations 2020 chlor_a: per-polygon ingest ===\n")
t0 <- Sys.time()
ingest_satellite("chlor_a", 2020, "stations")
cat(sprintf("Stations ingest wall time: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

stations_daily <- extract_satellite("chlor_a", 2020, "stations")
stations_8day  <- composite_to_8day(stations_daily)

cat(sprintf("Stations daily rows: %d ; 8-day rows: %d (expect 2 * 46 = 92)\n",
            nrow(stations_daily), nrow(stations_8day)))

cat("\nStations 8-day summary:\n")
stations_8day |>
  group_by(polygon_id) |>
  summarise(n_valid_windows  = sum(!sparse),
            n_sparse_windows = sum(sparse),
            seasonal_max     = max(value_mean, na.rm = TRUE),
            doy_at_max       = window_doy_start[which.max(value_mean)]) |>
  print()

p_stations <- ggplot(stations_8day,
                     aes(window_doy_start, value_mean, color = polygon_id)) +
  geom_line() + geom_point() +
  geom_point(data = filter(stations_8day, sparse),
             aes(window_doy_start, value_mean),
             shape = 1, color = "grey60", size = 3) +
  labs(x = "8-day window start DOY", y = "chlor_a (mg m^-3)",
       title = "Stations 2020 chlor_a, 8-day composites",
       subtitle = "open circles = sparse windows (n_valid_pixels < 22)") +
  theme_minimal()

ggsave("plots/satellite/verify_session_b_stations_2020.png",
       p_stations, width = 9, height = 5, dpi = 110)
cat("Saved: plots/satellite/verify_session_b_stations_2020.png\n")


# -----------------------------------------------------------------------------
# 3) CINAR/GMB150 only: ingest one polygon to verify the spring bloom signal
# -----------------------------------------------------------------------------
cat("\n=== CINAR/GMB150 2020 chlor_a: single-polygon ingest ===\n")
t0 <- Sys.time()
ingest_satellite("chlor_a", 2020, "cinar", polygon_ids = "GMB150")
cat(sprintf("GMB150 ingest wall time: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

cinar_daily <- extract_satellite("chlor_a", 2020, "cinar")
cinar_8day  <- composite_to_8day(cinar_daily)

gmb <- cinar_8day |> filter(polygon_id == "GMB150")
cat(sprintf("\nGMB150: %d 8-day rows, %d valid, %d sparse\n",
            nrow(gmb), sum(!gmb$sparse), sum(gmb$sparse)))

cat("\nGMB150 2020 8-day seasonal cycle (expect spring bloom DOY 80-140):\n")
print(gmb |> dplyr::select(window_doy_start, value_mean, value_sd,
                           n_valid_pixels, n_days_with_data, sparse))

if (any(!is.na(gmb$value_mean))) {
  i_max <- which.max(gmb$value_mean)
  cat(sprintf("\nGMB150 seasonal max: %.2f mg m^-3 at window DOY %d\n",
              gmb$value_mean[i_max], gmb$window_doy_start[i_max]))
}

p_gmb <- ggplot(gmb, aes(window_doy_start, value_mean)) +
  geom_line(color = "darkgreen") +
  geom_point(color = "darkgreen") +
  geom_errorbar(aes(ymin = value_mean - value_sd,
                    ymax = value_mean + value_sd),
                color = "darkgreen", width = 2, alpha = 0.5) +
  geom_point(data = filter(gmb, sparse),
             shape = 1, color = "grey60", size = 3) +
  labs(x = "8-day window start DOY", y = "chlor_a (mg m^-3)",
       title = "CINAR / GMB150 2020 chlor_a, 8-day composites",
       subtitle = "expect spring bloom DOY ~80-140; open circles = n < 22") +
  theme_minimal()

ggsave("plots/satellite/verify_session_b_gmb150_2020.png",
       p_gmb, width = 9, height = 5, dpi = 110)
cat("Saved: plots/satellite/verify_session_b_gmb150_2020.png\n")

cat("\n=== Session B verification complete ===\n")
