# =============================================================================
# WP6 Session A — Verification Script
#
# One-off check that the satellite ingest layer works end-to-end. Not part
# of the production pipeline. Run interactively from the project root with
#   source("R/04_satellite_products/verify_session_a.R")
#
# What it does:
#   1. Sources satellite_config.R and satellite_ingest.R
#   2. Prints the WBTS/CMTS station buffer sf and its areas (sanity check)
#   3. Shows the `stations` set's padded union bbox
#   4. Downloads chlor_a 2020 for that bbox to
#      data/satellite/raw/stations_chlor_a_2020.nc
#   5. Opens the NetCDF and spot-checks the CMTS pixel's 2020 seasonal cycle
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(ncdf4)
  library(units)
})

source("R/04_satellite_products/satellite_config.R")
source("R/04_satellite_products/satellite_ingest.R")

# -----------------------------------------------------------------------------
# 1) Station buffer sf — built at config load time
# -----------------------------------------------------------------------------
cat("\n=== Station buffers ===\n")
print(satellite_config$station_buffers_sf)

buffer_areas_km2 <- st_area(satellite_config$station_buffers_sf) |>
  set_units("km^2")
expected_area <- pi * (satellite_config$station_buffer_m / 1000)^2
cat("\nBuffer areas (expected ~", round(expected_area, 1), " km^2 each):\n",
    sep = "")
print(buffer_areas_km2)

# -----------------------------------------------------------------------------
# 2) Stations geography-set bbox (padded)
# -----------------------------------------------------------------------------
bb <- satellite_bbox("stations")
cat(sprintf("\nStations request bbox (pad = %.3f deg):\n",
            satellite_config$bbox_pad_deg))
cat(sprintf("  lon: [%.4f, %.4f]   span = %.3f deg\n",
            bb$lon_min, bb$lon_max, bb$lon_max - bb$lon_min))
cat(sprintf("  lat: [%.4f, %.4f]   span = %.3f deg\n",
            bb$lat_min, bb$lat_max, bb$lat_max - bb$lat_min))

# -----------------------------------------------------------------------------
# 3) Download chlor_a 2020 for the stations set (resumable)
# -----------------------------------------------------------------------------
cat("\n=== Ingest chlor_a 2020 (stations) ===\n")
t0 <- Sys.time()
target <- ingest_satellite("chlor_a", 2020, geography_set = "stations")
cat(sprintf("Wall time: %.1f s\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

if (is.null(target) || !file.exists(target)) {
  stop("Ingest failed: no file at expected path.")
}

cat(sprintf("Cached file: %s\n", target))
cat(sprintf("File size:   %.2f MB\n", file.info(target)$size / 1024^2))

# -----------------------------------------------------------------------------
# 4) Inspect the NetCDF
# -----------------------------------------------------------------------------
cat("\n=== NetCDF structure ===\n")
nc <- nc_open(target)
print(nc)

lon  <- ncvar_get(nc, "longitude")
lat  <- ncvar_get(nc, "latitude")
time <- as.Date(ncvar_get(nc, "time") / 86400, origin = "1970-01-01")

cat(sprintf("\nLongitude: %d cells, range [%.3f, %.3f]\n",
            length(lon), min(lon), max(lon)))
cat(sprintf("Latitude:  %d cells, range [%.3f, %.3f]\n",
            length(lat), min(lat), max(lat)))
cat(sprintf("Time:      %d days, range [%s, %s]\n",
            length(time), min(time), max(time)))

# -----------------------------------------------------------------------------
# 5) Spot-check CMTS pixel (43.75 N, -68.481 E) seasonal cycle
# -----------------------------------------------------------------------------
i_lon <- which.min(abs(lon - (-68.481)))
i_lat <- which.min(abs(lat -   43.75 ))

cat(sprintf("\nCMTS nearest pixel: lon = %.4f, lat = %.4f\n",
            lon[i_lon], lat[i_lat]))

chl_cmts <- ncvar_get(nc, "chlor_a",
                      start = c(i_lon, i_lat, 1),
                      count = c(1, 1, length(time)))

cat("\nCMTS chlor_a 2020 summary (mg m^-3):\n")
print(summary(chl_cmts))
cat(sprintf("Non-NA days: %d / %d (%.0f%%)\n",
            sum(!is.na(chl_cmts)), length(chl_cmts),
            100 * mean(!is.na(chl_cmts))))

if (any(!is.na(chl_cmts))) {
  i_max <- which.max(chl_cmts)
  cat(sprintf("Seasonal max: %.2f mg m^-3 on %s (DOY %d)\n",
              chl_cmts[i_max], time[i_max],
              as.integer(format(time[i_max], "%j"))))
}

# Quick PNG so you can eyeball the seasonal cycle
plot_path <- file.path("plots", "satellite", "verify_session_a_cmts_2020.png")
if (!dir.exists(dirname(plot_path))) {
  dir.create(dirname(plot_path), recursive = TRUE, showWarnings = FALSE)
}
png(plot_path, width = 900, height = 500, res = 110)
plot(time, chl_cmts, type = "l", col = "darkgreen",
     ylab = "chlor_a (mg m^-3)", xlab = "2020",
     main = "Session A verification: OC-CCI chlor_a at CMTS pixel, 2020")
abline(h = mean(chl_cmts, na.rm = TRUE), lty = 2, col = "grey50")
dev.off()
cat(sprintf("\nPlot saved: %s\n", plot_path))

nc_close(nc)

cat("\n=== Session A verification complete ===\n")
