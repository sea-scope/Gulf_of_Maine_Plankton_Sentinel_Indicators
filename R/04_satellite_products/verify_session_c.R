# =============================================================================
# WP6 Session C — Verification Script
#
# Run from project root:
#   source("R/04_satellite_products/verify_session_c.R")
#
# Goals:
#   1. Re-extract + re-composite the Session B cache (stations/WBTS,
#      stations/CMTS, cinar/GMB150 — all 2020 chl_a) with the new
#      methodology:
#        - 12 km block averaging before exact_extract
#        - sufficient statistics propagated through compositing
#        - pooled within-window pixel SD
#      No new OC-CCI downloads — uses cached NetCDFs.
#   2. Compare the new pooled SD against the old between-day-of-daily-means
#      SD. Expect new SD to be noticeably larger (3-10x is the rough target
#      from the brief) because it now includes within-day spatial variation.
#   3. Confirm GMB150's 2020 seasonal MAX is unchanged in shape — block
#      averaging should shift values slightly but the seasonal cycle should
#      still peak at DOY 241 (late August), matching Session B.
#   4. Confirm the OISST dataset ID (`ncdcOisst21Agg_LonPM180` on NOAA
#      CoastWatch ERDDAP) by issuing a small test griddap request — one
#      polygon (CMTS buffer), one year (2020). Inspect field name, units,
#      and dimensions. Document the confirmed values for satellite_config.R.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(rerddap)
  library(terra)
  library(ncdf4)
})

source("R/04_satellite_products/satellite_config.R")
source("R/04_satellite_products/satellite_ingest.R")
source("R/04_satellite_products/satellite_extract.R")
source("R/04_satellite_products/satellite_composite.R")


# -----------------------------------------------------------------------------
# Helper: compute Session B "old-style" between-day SD from the new extract
# output, so we can compare side-by-side without re-running the old code.
#
# Old composite did: value_sd = sd(variable_mean) across the days in the
# window. variable_mean here is the polygon mean of the *coarsened* daily
# raster — slightly different from Session B's uncoarsened daily mean, but
# captures the same between-day-of-daily-means signal that the old SD
# represented. The point of the comparison is the order-of-magnitude
# difference once within-day spatial variation is also included.
# -----------------------------------------------------------------------------
old_style_composite <- function(daily_df, config = satellite_config) {
  win_info <- assign_8day_window(daily_df$date, config$window_start_doy)
  d <- bind_cols(daily_df, win_info)
  d |>
    group_by(geography_set, polygon_id, variable,
             year, window_num, window_doy_start) |>
    summarise(
      value_mean_old = mean(variable_mean, na.rm = TRUE),
      value_sd_old   = stats::sd(variable_mean, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(value_mean_old = ifelse(is.nan(value_mean_old), NA_real_,
                                   value_mean_old))
}


# -----------------------------------------------------------------------------
# 1) Stations 2020 chlor_a: re-extract from cache, recompose with new methods
# -----------------------------------------------------------------------------
cat("\n=== Stations 2020 chlor_a: re-extract from cache (block_fact = 3) ===\n")
stations_daily <- extract_satellite("chlor_a", 2020, "stations")

stations_new <- composite_to_8day(stations_daily)
stations_old <- old_style_composite(stations_daily)

stations_cmp <- stations_new |>
  left_join(stations_old,
            by = c("geography_set", "polygon_id", "variable",
                   "year", "window_num", "window_doy_start")) |>
  mutate(sd_ratio = value_sd / value_sd_old)

cat("\nStations: per-polygon row counts by sparse status (5 km buffer vs 12 km blocks):\n")
stations_cmp |>
  group_by(polygon_id) |>
  summarise(
    n_windows_total  = n(),
    n_sparse         = sum(sparse),
    n_with_old_sd    = sum(!is.na(value_sd_old) & value_sd_old > 0),
    max_n_pixels     = max(n_valid_pixels, na.rm = TRUE)
  ) |>
  print()

cat("\nStations: new pooled SD vs old between-day SD (all windows where both are defined):\n")
stations_cmp |>
  filter(!is.na(value_sd_old), value_sd_old > 0, !is.na(value_sd)) |>
  group_by(polygon_id) |>
  summarise(
    n_windows    = n(),
    mean_new_sd  = round(mean(value_sd,     na.rm = TRUE), 3),
    mean_old_sd  = round(mean(value_sd_old, na.rm = TRUE), 3),
    median_ratio = round(median(sd_ratio,   na.rm = TRUE), 2),
    p25_ratio    = round(quantile(sd_ratio, 0.25, na.rm = TRUE), 2),
    p75_ratio    = round(quantile(sd_ratio, 0.75, na.rm = TRUE), 2),
    .groups      = "drop"
  ) |>
  print()


# -----------------------------------------------------------------------------
# 2) CINAR/GMB150 2020 chlor_a: re-extract from cache, recompose with new methods
# -----------------------------------------------------------------------------
cat("\n=== CINAR/GMB150 2020 chlor_a: re-extract from cache (block_fact = 3) ===\n")
cinar_daily <- extract_satellite("chlor_a", 2020, "cinar")

cinar_new <- composite_to_8day(cinar_daily)
cinar_old <- old_style_composite(cinar_daily)

gmb_new <- cinar_new |> filter(polygon_id == "GMB150")
gmb_old <- cinar_old |> filter(polygon_id == "GMB150")

gmb_cmp <- gmb_new |>
  left_join(gmb_old,
            by = c("geography_set", "polygon_id", "variable",
                   "year", "window_num", "window_doy_start")) |>
  mutate(sd_ratio = value_sd / value_sd_old)

cat("\nGMB150 8-day rows (new value_mean, new pooled SD, old between-day SD, ratio):\n")
gmb_cmp |>
  select(window_doy_start, value_mean, value_sd, value_sd_old,
         sd_ratio, n_valid_pixels, n_days_with_data, sparse) |>
  print(n = Inf)

cat("\nGMB150: summary of new/old SD ratio across windows with both SDs defined:\n")
gmb_cmp |>
  filter(!is.na(value_sd_old), value_sd_old > 0, !is.na(value_sd)) |>
  summarise(
    n_windows       = n(),
    n_nonsparse     = sum(!sparse),
    mean_new_sd     = round(mean(value_sd,     na.rm = TRUE), 3),
    mean_old_sd     = round(mean(value_sd_old, na.rm = TRUE), 3),
    median_ratio    = round(median(sd_ratio,   na.rm = TRUE), 2),
    p25_ratio       = round(quantile(sd_ratio, 0.25, na.rm = TRUE), 2),
    p75_ratio       = round(quantile(sd_ratio, 0.75, na.rm = TRUE), 2)
  ) |>
  print()

# Seasonal-shape sanity check: max value should still land at DOY 241
# (Session B reported 2.67 mg m^-3 at DOY 241 = late August).
if (any(!is.na(gmb_new$value_mean))) {
  i_max <- which.max(gmb_new$value_mean)
  cat(sprintf(
    "\nGMB150 seasonal max (new): %.2f mg m^-3 at window DOY %d (Session B: 2.67 at DOY 241)\n",
    gmb_new$value_mean[i_max], gmb_new$window_doy_start[i_max]
  ))
}


# -----------------------------------------------------------------------------
# 3) Plots — new pooled SD as error bars
# -----------------------------------------------------------------------------
p_stations <- ggplot(stations_new,
                     aes(window_doy_start, value_mean, color = polygon_id)) +
  geom_line() +
  geom_point() +
  geom_errorbar(aes(ymin = value_mean - value_sd,
                    ymax = value_mean + value_sd),
                width = 2, alpha = 0.5) +
  geom_point(data = filter(stations_new, sparse),
             shape = 1, color = "grey60", size = 3) +
  labs(x = "8-day window start DOY", y = "chlor_a (mg m^-3)",
       title = "Session C: Stations 2020 chlor_a — block-avg + pooled pixel SD",
       subtitle = "open circles = sparse windows (n_valid_pixels < 22)") +
  theme_minimal()

ggsave("plots/satellite/verify_session_c_stations_2020.png",
       p_stations, width = 9, height = 5, dpi = 110)
cat("\nSaved: plots/satellite/verify_session_c_stations_2020.png\n")

p_gmb <- ggplot(gmb_new, aes(window_doy_start, value_mean)) +
  geom_line(color = "darkgreen") +
  geom_point(color = "darkgreen") +
  geom_errorbar(aes(ymin = value_mean - value_sd,
                    ymax = value_mean + value_sd),
                color = "darkgreen", width = 2, alpha = 0.5) +
  geom_point(data = filter(gmb_new, sparse),
             shape = 1, color = "grey60", size = 3) +
  labs(x = "8-day window start DOY", y = "chlor_a (mg m^-3)",
       title = "Session C: CINAR / GMB150 2020 chlor_a — block-avg + pooled pixel SD",
       subtitle = "expect seasonal max at DOY ~241 (matching Session B)") +
  theme_minimal()

ggsave("plots/satellite/verify_session_c_gmb150_2020.png",
       p_gmb, width = 9, height = 5, dpi = 110)
cat("Saved: plots/satellite/verify_session_c_gmb150_2020.png\n")


# -----------------------------------------------------------------------------
# 4) OISST dataset confirmation
#
# Tentative dataset ID is `ncdcOisst21Agg_LonPM180` on NOAA CoastWatch ERDDAP
# (https://coastwatch.pfeg.noaa.gov/erddap). Verify the dataset exists, the
# field name is `sst`, units are degC, and the fill value is reasonable.
# A single small test request (CMTS station buffer, 2020 only) is enough.
# -----------------------------------------------------------------------------
cat("\n=== OISST dataset confirmation ===\n")

sst_cfg <- satellite_config$sst
cat(sprintf("Attempting rerddap::info('%s', url = '%s')\n",
            sst_cfg$dataset_id, sst_cfg$erddap_url))

oisst_info <- tryCatch(
  rerddap::info(sst_cfg$dataset_id, url = sst_cfg$erddap_url),
  error = function(e) {
    message("FAILED to fetch dataset info: ", conditionMessage(e))
    NULL
  }
)

if (!is.null(oisst_info)) {
  cat("\n--- OISST dataset metadata ---\n")
  print(oisst_info)

  cat("\n--- Variables in dataset ---\n")
  print(oisst_info$variables)

  # Dump the global + variable attributes for fill_value, units, etc.
  vars_alldata <- tryCatch(oisst_info$alldata, error = function(e) NULL)
  if (!is.null(vars_alldata) && "sst" %in% names(vars_alldata)) {
    cat("\n--- 'sst' variable attributes (units, fill value, etc.) ---\n")
    sst_attrs <- vars_alldata$sst
    keep <- sst_attrs$attribute_name %in%
      c("units", "long_name", "standard_name",
        "_FillValue", "missing_value",
        "valid_min", "valid_max", "actual_range")
    print(sst_attrs[keep, c("attribute_name", "value")])
  }
}

# Small test request: CMTS buffer, full year 2020. Use the existing
# satellite_ingest path so any zlev/dimension issues surface there.
cat("\nIssuing small OISST test request: CMTS buffer, 2020 ...\n")
oisst_paths <- tryCatch(
  ingest_satellite("sst", 2020, "stations",
                   polygon_ids = "CMTS",
                   overwrite   = FALSE),
  error = function(e) {
    message("FAILED OISST ingest: ", conditionMessage(e))
    NULL
  }
)

if (!is.null(oisst_paths) && !is.null(oisst_paths$CMTS) &&
    file.exists(oisst_paths$CMTS)) {

  cat(sprintf("OISST cache: %s (%.2f KB)\n",
              oisst_paths$CMTS,
              file.info(oisst_paths$CMTS)$size / 1024))

  nc <- ncdf4::nc_open(oisst_paths$CMTS)
  cat("\n--- NetCDF variables ---\n")
  print(names(nc$var))
  cat("\n--- NetCDF dimensions ---\n")
  print(sapply(nc$dim, function(d) d$len))

  sst_units <- ncdf4::ncatt_get(nc, "sst", "units")$value
  sst_fill  <- ncdf4::ncatt_get(nc, "sst", "_FillValue")$value
  cat(sprintf("\nField 'sst' units: %s   _FillValue: %s\n",
              sst_units, format(sst_fill)))

  # Probe a few values to confirm degC range
  sst_arr <- ncdf4::ncvar_get(nc, "sst")
  ncdf4::nc_close(nc)
  cat(sprintf("'sst' value range (drop NA): [%.2f, %.2f], n = %d, n_NA = %d\n",
              suppressWarnings(min(sst_arr, na.rm = TRUE)),
              suppressWarnings(max(sst_arr, na.rm = TRUE)),
              length(sst_arr), sum(is.na(sst_arr))))

  # Round-trip through extract: should produce ~365 daily rows
  cat("\nRunning extract_satellite('sst', 2020, 'stations') to confirm the\n")
  cat("downstream path (block_fact = 1, no coarsening) ...\n")
  oisst_daily <- extract_satellite("sst", 2020, "stations")
  cat(sprintf("OISST CMTS daily rows: %d ; mean SST (where valid): %.2f degC\n",
              sum(oisst_daily$polygon_id == "CMTS"),
              mean(oisst_daily$variable_mean[oisst_daily$polygon_id == "CMTS"],
                   na.rm = TRUE)))

  oisst_8day <- composite_to_8day(oisst_daily)
  cat(sprintf("OISST CMTS 8-day rows: %d ; valid: %d ; sparse: %d\n",
              sum(oisst_8day$polygon_id == "CMTS"),
              sum(oisst_8day$polygon_id == "CMTS" & !oisst_8day$sparse),
              sum(oisst_8day$polygon_id == "CMTS" &  oisst_8day$sparse)))
}

cat("\n=== Session C verification complete ===\n")
