# =============================================================================
# Satellite Products — 8-day Compositing Layer
#
# Takes the long-format output of `extract_satellite()` (one row per
# polygon * date carrying sufficient statistics) and aggregates to 8-day
# MODIS-convention windows (DOY 1, 9, 17, ..., 361). Each window covers 8
# days except the last window of the year which covers DOY 361-365 (or
# DOY 361-366 in leap years).
#
# Returns a data frame with one row per (geography_set, polygon_id, variable,
# year, window_num, window_doy_start). Within each window the daily sufficient
# statistics are pooled to produce:
#   - value_mean = sum(sum_wx)  / sum(sum_w)
#   - value_sd   = sqrt( (sum(sum_wxx) / sum(sum_w) - value_mean^2) * N / (N-1) )
#                 where N = sum(n_valid_pixels) across the window's days
#
# This `value_sd` is the "8-day pixel SD" — it pools *within-day spatial
# variability* (variability across the ~12 km blocks inside the polygon on a
# given day) and *between-day temporal variability* (how the polygon mean
# changes day-to-day across the window) into a single coverage-fraction-
# weighted estimator with a Bessel correction on the total pixel-day count.
#
# Reported `n_valid_pixels` is the maximum daily pixel count across the
# window's days (the polygon's pixel capacity on its clearest day), used for
# the sparse threshold against config$n_min.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

if (!exists("satellite_config")) {
  source(file.path("R", "04_satellite_products", "satellite_config.R"))
}


#' Assign a date to its MODIS 8-day window number (1-46) and window start DOY
#'
#' @param d Date vector.
#' @param window_starts Integer vector of window-start DOYs from
#'   `satellite_config$window_start_doy`.
#'
#' @return Data frame with columns `year`, `doy`, `window_num`, and
#'   `window_doy_start`, one row per input date.
assign_8day_window <- function(d, window_starts = satellite_config$window_start_doy) {
  yr  <- lubridate::year(d)
  doy <- lubridate::yday(d)
  win <- findInterval(doy, window_starts)
  data.frame(
    year             = yr,
    doy              = doy,
    window_num       = win,
    window_doy_start = window_starts[win]
  )
}


#' Aggregate daily polygon sufficient statistics into 8-day pooled composites
#'
#' @param daily_df Output of `extract_satellite()`. Required columns:
#'   geography_set, polygon_id, date, variable, sum_w, sum_wx, sum_wxx,
#'   n_valid_pixels. (variable_mean is allowed for backward eyeballing but
#'   not consumed here — value_mean is re-derived from the sufficient stats.)
#' @param config   List. Defaults to satellite_config.
#'
#' @return Long-format data frame: geography_set, polygon_id, variable, year,
#'   window_num, window_doy_start, value_mean, value_sd, n_valid_pixels,
#'   n_days_with_data, n_pixel_obs, sparse. `n_pixel_obs` is the total count
#'   of (block, day) observations contributing to value_mean / value_sd across
#'   the window — used downstream for inverse-SE^2 GAM weighting.
composite_to_8day <- function(daily_df, config = satellite_config) {
  required <- c("geography_set", "polygon_id", "date", "variable",
                "sum_w", "sum_wx", "sum_wxx", "n_valid_pixels")
  missing  <- setdiff(required, names(daily_df))
  if (length(missing) > 0L) {
    stop("composite_to_8day: missing required columns: ",
         paste(missing, collapse = ", "),
         ". Re-run extract_satellite() — Session C changed its schema.")
  }

  win_info <- assign_8day_window(daily_df$date, config$window_start_doy)
  d <- bind_cols(daily_df, win_info)

  d |>
    group_by(geography_set, polygon_id, variable,
             year, window_num, window_doy_start) |>
    summarise(
      sum_w_tot        = sum(sum_w,   na.rm = TRUE),
      sum_wx_tot       = sum(sum_wx,  na.rm = TRUE),
      sum_wxx_tot      = sum(sum_wxx, na.rm = TRUE),
      n_pixel_obs      = sum(n_valid_pixels, na.rm = TRUE),
      # n_days_with_data and n_valid_pixels both derive from the per-day
      # n_valid_pixels vector. Compute into a temporary, then reassign so
      # both are stable regardless of dplyr's summarise column-evaluation
      # order (the original "compute n_days_with_data before n_valid_pixels"
      # ordering worked but was fragile to dplyr version changes).
      .n_days_tmp      = sum(n_valid_pixels > 0L),
      .n_max_tmp       = suppressWarnings(max(n_valid_pixels, na.rm = TRUE)),
      n_days_with_data = .n_days_tmp,
      n_valid_pixels   = .n_max_tmp,
      .groups = "drop"
    ) |>
    # .n_days_tmp and .n_max_tmp get dropped at the final select() below.
    mutate(
      value_mean = ifelse(sum_w_tot > 0,
                          sum_wx_tot / sum_w_tot,
                          NA_real_),
      # Weighted second moment, clamped at 0 to absorb floating-point
      # underflow on near-zero-variance windows.
      .var_uncorr = pmax(
        ifelse(sum_w_tot > 0,
               sum_wxx_tot / sum_w_tot - value_mean^2,
               NA_real_),
        0
      ),
      # Bessel correction on total pixel-day observation count.
      value_sd = ifelse(n_pixel_obs > 1L,
                        sqrt(.var_uncorr * n_pixel_obs / (n_pixel_obs - 1L)),
                        NA_real_),
      n_valid_pixels = ifelse(is.infinite(n_valid_pixels),
                              0L, as.integer(n_valid_pixels)),
      # Per-row n_min lookup: walks (set, polygon, variable) -> per-variable
      # -> global. See satellite_config.R `.satellite_n_min()` for the hierarchy.
      n_min_row = .satellite_n_min_vec(geography_set, polygon_id, variable,
                                       config = config),
      sparse = n_valid_pixels < n_min_row
    ) |>
    select(geography_set, polygon_id, variable,
           year, window_num, window_doy_start,
           value_mean, value_sd,
           n_valid_pixels, n_days_with_data, n_pixel_obs, sparse) |>
    arrange(geography_set, polygon_id, variable, year, window_num)
}
