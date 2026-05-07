# =============================================================================
# Sentinel Indicators — Prediction, Baseline, and Anomaly Computation
#
# Functions for generating GAM predictions, computing reference-period
# baselines, and calculating anomalies with uncertainty propagation.
#
# Functions:
#   predict_seasonal()       — predictions across year range at a given DOY
#   predict_phenology()      — predictions across DOY range at a given year
#   compute_baseline()       — reference-period baseline mean and SD
#   get_mid_season_doy()     — mid-season DOY for a station/season
#   compute_anomaly()        — anomalies with posterior/naive/zscore uncertainty
#   compute_all_anomalies()  — orchestrate anomalies across all models
#   build_dashboard()        — sentinel dashboard CSV
#   sanity_check_anomalies() — verify baseline anomalies average ~zero
#   compute_reference_curve() — 365-point reference-period phenology curve
#   enrich_prepared_data()   — add reference_difference columns to prepared data
# =============================================================================

library(mgcv)
library(dplyr)

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# Mid-season DOY values (from reference scripts)
# These are the DOY values at which seasonal predictions are evaluated.
#
# CMTS winter: the reference script (CMTS_Sentinel_Index.R) used ad-hoc
# variable-specific DOY values for winter predictions (CI=275, CSI=402,
# DW=333), likely chosen to place the fitted line near the peak of each
# variable's winter distribution. This pipeline standardizes to DOY 37
# (adjusted to 402) for all CMTS winter variables, matching the WBTS
# convention and providing a consistent mid-winter evaluation point.
# This affects absolute fitted values but not year-over-year trends.
# =============================================================================

mid_season_doy <- list(
  WBTS = list(spring = 110, summer = 197, fall = 306, winter = 37),
  CMTS = list(spring = 110, summer = 197, winter = 37)
)

# For CMTS winter, we need the adjusted DOY for prediction
mid_season_doy_adj <- list(
  CMTS = list(winter = 37 + 365)  # = 402
)

# =============================================================================
# get_mid_season_doy()
# =============================================================================

get_mid_season_doy <- function(station_id, season) {
  doy <- mid_season_doy[[station_id]][[season]]
  if (is.null(doy)) stop("No mid-season DOY for ", station_id, "/", season)
  return(doy)
}

# =============================================================================
# predict_seasonal()
#
# Generate predictions from a seasonal GAM across a range of years at a
# fixed DOY (the mid-season day). Returns predictions on the model scale
# (sqrt for CI/DW, natural for CSI).
#
# Parameters:
#   model       — fitted gam object
#   year_range  — integer vector of years
#   doy         — day of year for prediction
#   doy_varname — name of DOY variable in model ("day_of_year" or "day_of_year_adj")
#
# Returns: data frame with year, fit, se_fit, fit_low, fit_high (model scale)
# =============================================================================

predict_seasonal <- function(model, year_range, doy, doy_varname = "day_of_year") {
  pred_grid <- data.frame(year = year_range)
  pred_grid[[doy_varname]] <- doy

  preds <- predict(model, newdata = pred_grid, type = "response", se.fit = TRUE)

  data.frame(
    year     = year_range,
    fit      = as.numeric(preds$fit),
    se_fit   = as.numeric(preds$se.fit),
    fit_low  = as.numeric(preds$fit - 1.96 * preds$se.fit),
    fit_high = as.numeric(preds$fit + 1.96 * preds$se.fit)
  )
}

# =============================================================================
# predict_phenology()
#
# Generate predictions from a phenology GAM across DOY 1:365 at a fixed year.
# Used for phenology plots.
#
# Parameters:
#   model — fitted gam object (phenology model with cyclic DOY spline)
#   year  — year to hold constant (typically median year)
#
# Returns: data frame with day_of_year, fit, se_fit, fit_low, fit_high
# =============================================================================

predict_phenology <- function(model, year) {
  pred_grid <- data.frame(day_of_year = 1:365, year = year)
  preds <- predict(model, newdata = pred_grid, type = "response", se.fit = TRUE)

  data.frame(
    day_of_year = 1:365,
    fit         = as.numeric(preds$fit),
    se_fit      = as.numeric(preds$se.fit),
    fit_low     = as.numeric(preds$fit - 1.96 * preds$se.fit),
    fit_high    = as.numeric(preds$fit + 1.96 * preds$se.fit)
  )
}

# =============================================================================
# compute_baseline()
#
# Compute the reference-period baseline from a seasonal GAM.
# For CI and DW (sqrt-transformed models), the baseline is computed on the
# natural scale by squaring the fitted values before averaging.
# For CSI (untransformed), the baseline is just the mean of fitted values.
#
# Parameters:
#   model           — fitted gam object
#   reference_years — integer vector of baseline years
#   doy             — mid-season DOY
#   doy_varname     — DOY variable name in model
#   is_sqrt         — logical; TRUE if the model uses sqrt transform (CI, DW)
#
# Returns: list with baseline_mean, baseline_sd, n_years, fits_natural
# =============================================================================

compute_baseline <- function(model, reference_years, doy, doy_varname = "day_of_year",
                             is_sqrt = FALSE) {
  preds <- predict_seasonal(model, reference_years, doy, doy_varname)

  if (is_sqrt) {
    # Back-transform to natural scale
    fits_natural <- preds$fit^2
  } else {
    fits_natural <- preds$fit
  }

  list(
    baseline_mean = mean(fits_natural),
    baseline_sd   = sd(fits_natural),
    n_years       = length(reference_years),
    fits_natural  = fits_natural,
    fits_model_scale = preds$fit
  )
}

# =============================================================================
# generate_all_predictions()
#
# Orchestrates prediction generation for all models in a fit result.
# Produces long-format and wide-format prediction tables matching the
# reference script output.
#
# Parameters:
#   fit_result — output of fit_sentinel_gams()
#
# Returns: list with $long (long-format predictions), $wide (wide-format)
# =============================================================================

generate_all_predictions <- function(fit_result) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  models <- fit_result$models

  # Year range from the data
  all_years <- sort(unique(c(
    fit_result$data$ci_data$year,
    fit_result$data$csi_data$year,
    fit_result$data$dw_data$year
  )))
  year_range <- seq(min(all_years), max(all_years))

  seasons <- names(cfg$season_boundaries)
  ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])

  results_long <- list()
  baselines <- list()

  # --- Phenology predictions ---
  mid_year <- round(median(year_range))
  for (var in c("CI", "CSI", "DW")) {
    mkey <- paste0("phenology_", var)
    if (!mkey %in% names(models)) next

    preds <- predict_phenology(models[[mkey]], mid_year)
    is_sqrt <- var %in% c("CI", "DW")
    preds$fit_natural <- if (is_sqrt) preds$fit^2 else preds$fit

    preds$station  <- station_id
    preds$variable <- var
    preds$season   <- "phenology"
    preds$year     <- mid_year
    preds$scale    <- if (is_sqrt) "sqrt" else "natural"

    results_long[[mkey]] <- preds[, c("station", "year", "day_of_year",
                                       "variable", "season", "fit", "se_fit",
                                       "fit_natural", "scale")]
  }

  # --- Seasonal predictions ---
  for (var in c("CI", "CSI", "DW")) {
    is_sqrt <- var %in% c("CI", "DW")

    for (ssn in seasons) {
      mkey <- paste0(ssn, "_", var)
      if (!mkey %in% names(models)) next

      # Determine DOY variable and value
      doy_varname <- "day_of_year"
      doy_val <- get_mid_season_doy(station_id, ssn)

      if (cfg$n_seasons == 3 && ssn == "winter") {
        doy_varname <- "day_of_year_adj"
        doy_val <- mid_season_doy_adj[["CMTS"]][["winter"]]
      }

      preds <- predict_seasonal(models[[mkey]], year_range, doy_val, doy_varname)
      preds$fit_natural <- if (is_sqrt) preds$fit^2 else preds$fit

      preds$station     <- station_id
      preds$variable    <- var
      preds$season      <- ssn
      preds$day_of_year <- doy_val
      preds$scale       <- if (is_sqrt) "sqrt" else "natural"

      results_long[[mkey]] <- preds[, c("station", "year", "day_of_year",
                                         "variable", "season", "fit", "se_fit",
                                         "fit_natural", "scale")]

      # Compute baseline
      bl <- compute_baseline(models[[mkey]], ref_years, doy_val, doy_varname, is_sqrt)
      baselines[[mkey]] <- data.frame(
        station         = station_id,
        variable        = var,
        season          = ssn,
        reference_start = cfg$reference_period[1],
        reference_end   = cfg$reference_period[2],
        n_years         = bl$n_years,
        baseline_mean   = round(bl$baseline_mean, 4),
        baseline_sd     = round(bl$baseline_sd, 4),
        stringsAsFactors = FALSE
      )
    }
  }

  pred_long <- do.call(rbind, results_long)
  rownames(pred_long) <- NULL

  baseline_df <- do.call(rbind, baselines)
  rownames(baseline_df) <- NULL

  # --- Wide format (seasonal only, matches reference script output) ---
  seasonal_only <- pred_long %>%
    filter(season != "phenology") %>%
    dplyr::select(station, year, season, variable, fit_natural)

  pred_wide <- tryCatch({
    seasonal_only %>%
      tidyr::pivot_wider(
        names_from = c(variable, season),
        values_from = fit_natural,
        names_glue = "{variable}_{season}"
      )
  }, error = function(e) NULL)

  list(
    long      = pred_long,
    wide      = pred_wide,
    baselines = baseline_df
  )
}

# =============================================================================
# compute_anomaly()
#
# Compute anomalies for a seasonal GAM: fit(year) - baseline_mean, with
# uncertainty from posterior sampling (preferred), naive error propagation
# (fallback), or z-score (last resort).
#
# For sqrt-transformed models (CI, DW), back-transformation happens inside
# each posterior draw so the uncertainty is correct on the natural scale.
#
# Parameters:
#   model           — fitted gam object
#   focal_years     — integer vector of years to compute anomalies for
#   reference_years — integer vector of baseline years
#   doy             — mid-season DOY
#   doy_varname     — "day_of_year" or "day_of_year_adj"
#   is_sqrt         — TRUE if model uses sqrt transform
#   method          — "posterior" (try first), "naive", or "zscore"
#   n_draws         — number of posterior draws (default 1000)
#
# Returns: data frame with year, anomaly, anomaly_low, anomaly_high, z_score,
#          method_used
# =============================================================================

compute_anomaly <- function(model, focal_years, reference_years, doy,
                            doy_varname = "day_of_year", is_sqrt = FALSE,
                            method = c("posterior", "naive", "zscore"),
                            n_draws = 1000) {
  method <- match.arg(method)

  # Build prediction grids for focal and reference years
  all_years <- sort(unique(c(focal_years, reference_years)))
  pred_grid <- data.frame(year = all_years)
  pred_grid[[doy_varname]] <- doy

  # Get linear predictor matrix for all years
  Xp <- predict(model, newdata = pred_grid, type = "lpmatrix")
  ref_idx <- which(all_years %in% reference_years)

  result <- NULL

  # --- Method 1: Posterior sampling ---
  if (method == "posterior") {
    result <- tryCatch({
      beta <- coef(model)
      Vb <- vcov(model)
      draws <- MASS::mvrnorm(n = n_draws, mu = beta, Sigma = Vb)

      # Each draw: compute fitted values on model scale, then natural scale
      fit_draws <- Xp %*% t(draws)  # nrow = n_years, ncol = n_draws

      if (is_sqrt) {
        # Back-transform each draw to natural scale
        natural_draws <- fit_draws^2
      } else {
        natural_draws <- fit_draws
      }

      # Baseline mean per draw (mean of reference-year fitted values)
      baseline_draws <- colMeans(natural_draws[ref_idx, , drop = FALSE])

      # Anomaly per draw for each year
      anomaly_draws <- sweep(natural_draws, 2, baseline_draws, "-")

      # Summarize: point estimate and 95% credible interval
      anomaly_mean <- rowMeans(anomaly_draws)
      anomaly_lo <- apply(anomaly_draws, 1, quantile, probs = 0.025)
      anomaly_hi <- apply(anomaly_draws, 1, quantile, probs = 0.975)

      # Z-score: (value - baseline_mean) / baseline_sd
      # baseline_sd = interannual SD of fitted values across reference years
      # This can diverge from the anomaly CI: z captures "how unusual relative to
      # baseline spread" while the CI captures "how uncertain is the anomaly estimate"
      ref_fits_natural <- rowMeans(natural_draws[ref_idx, , drop = FALSE])
      baseline_mean_pt <- mean(ref_fits_natural)
      baseline_sd_pt <- sd(ref_fits_natural)
      focal_vals <- rowMeans(natural_draws)
      z_scores <- if (baseline_sd_pt > 0) {
        (focal_vals - baseline_mean_pt) / baseline_sd_pt
      } else {
        rep(NA_real_, length(focal_vals))
      }

      data.frame(
        year        = all_years,
        anomaly     = round(anomaly_mean, 4),
        anomaly_low = round(anomaly_lo, 4),
        anomaly_high = round(anomaly_hi, 4),
        z_score     = round(z_scores, 4),
        method_used = "posterior",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      cat("    Posterior sampling failed:", conditionMessage(e), "\n")
      NULL
    })
  }

  # --- Method 2: Naive error propagation (fallback) ---
  if (is.null(result) && method %in% c("posterior", "naive")) {
    result <- tryCatch({
      preds <- predict(model, newdata = pred_grid, type = "response", se.fit = TRUE)
      fits <- as.numeric(preds$fit)
      ses <- as.numeric(preds$se.fit)

      if (is_sqrt) {
        fits_natural <- fits^2
        # Delta method: se(x^2) ~ 2*x*se(x)
        ses_natural <- 2 * abs(fits) * ses
      } else {
        fits_natural <- fits
        ses_natural <- ses
      }

      baseline_mean <- mean(fits_natural[ref_idx])
      baseline_var <- var(fits_natural[ref_idx]) / length(ref_idx)
      baseline_sd_raw <- sd(fits_natural[ref_idx])

      anomalies <- fits_natural - baseline_mean
      # var(anomaly) ~ se_fit^2 + var(baseline)
      anomaly_se <- sqrt(ses_natural^2 + baseline_var)

      z_scores <- if (baseline_sd_raw > 0) {
        anomalies / baseline_sd_raw
      } else {
        rep(NA_real_, length(anomalies))
      }

      data.frame(
        year         = all_years,
        anomaly      = round(anomalies, 4),
        anomaly_low  = round(anomalies - 1.96 * anomaly_se, 4),
        anomaly_high = round(anomalies + 1.96 * anomaly_se, 4),
        z_score      = round(z_scores, 4),
        method_used  = "naive",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      cat("    Naive error propagation failed:", conditionMessage(e), "\n")
      NULL
    })
  }

  # --- Method 3: Z-score only (last resort, dashboard only) ---
  if (is.null(result)) {
    preds <- predict(model, newdata = pred_grid, type = "response", se.fit = TRUE)
    fits <- as.numeric(preds$fit)

    if (is_sqrt) {
      fits_natural <- fits^2
    } else {
      fits_natural <- fits
    }

    baseline_mean <- mean(fits_natural[ref_idx])
    baseline_sd <- sd(fits_natural[ref_idx])

    anomalies <- fits_natural - baseline_mean
    z_scores <- if (baseline_sd > 0) anomalies / baseline_sd else rep(NA_real_, length(anomalies))

    result <- data.frame(
      year         = all_years,
      anomaly      = round(anomalies, 4),
      anomaly_low  = NA_real_,
      anomaly_high = NA_real_,
      z_score      = round(z_scores, 4),
      method_used  = "zscore",
      stringsAsFactors = FALSE
    )
  }

  # Filter to focal years only
  result[result$year %in% focal_years, ]
}

# =============================================================================
# compute_all_anomalies()
#
# Orchestrates anomaly computation across all station × variable × season
# combinations. CSI is excluded per project decision.
#
# Parameters:
#   fit_results — named list of fit_sentinel_gams() results (one per station)
#
# Returns: data frame (anomalies_long format)
# =============================================================================

compute_all_anomalies <- function(fit_results) {
  all_anomalies <- list()

  for (stn in names(fit_results)) {
    fr <- fit_results[[stn]]
    cfg <- fr$config
    models <- fr$models
    seasons <- names(cfg$season_boundaries)
    ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])

    all_years <- sort(unique(c(
      fr$data$ci_data$year, fr$data$csi_data$year, fr$data$dw_data$year
    )))
    year_range <- seq(min(all_years), max(all_years))

    for (var in c("CI", "DW")) {  # CSI excluded from anomalies
      is_sqrt <- var %in% c("CI", "DW")

      for (ssn in seasons) {
        mkey <- paste0(ssn, "_", var)
        if (!mkey %in% names(models)) next

        doy_varname <- "day_of_year"
        doy_val <- get_mid_season_doy(stn, ssn)

        if (cfg$n_seasons == 3 && ssn == "winter") {
          doy_varname <- "day_of_year_adj"
          doy_val <- mid_season_doy_adj[["CMTS"]][["winter"]]
        }

        cat("  Computing anomalies:", stn, var, ssn, "... ")
        anom <- compute_anomaly(
          model = models[[mkey]],
          focal_years = year_range,
          reference_years = ref_years,
          doy = doy_val,
          doy_varname = doy_varname,
          is_sqrt = is_sqrt,
          method = "posterior"
        )

        anom$station  <- stn
        anom$variable <- var
        anom$season   <- ssn

        cat(anom$method_used[1], "\n")
        list_key <- paste0(stn, "_", mkey)
        all_anomalies[[list_key]] <- anom
      }
    }
  }

  anom_df <- do.call(rbind, all_anomalies)
  rownames(anom_df) <- NULL
  anom_df[, c("station", "year", "season", "variable", "anomaly",
              "anomaly_low", "anomaly_high", "z_score", "method_used")]
}

# =============================================================================
# build_dashboard()
#
# Builds sentinel_dashboard.csv: one row per station × variable × season
# (CSI excluded). Includes current value, anomaly, z-score, status, and
# trend over a configurable window.
#
# Parameters:
#   anomalies_df      — output of compute_all_anomalies()
#   predictions_df    — predictions_long from generate_all_predictions()
#   baselines_df      — baselines from generate_all_predictions()
#   trend_window_years — default trend window (overridden by station config)
#
# Returns: data frame
# =============================================================================

build_dashboard <- function(anomalies_df, predictions_df, baselines_df,
                            trend_window_years = 5) {
  # Get seasonal predictions (not phenology), natural scale
  seasonal_preds <- predictions_df %>%
    filter(season != "phenology") %>%
    dplyr::select(station, year, variable, season, fit_natural)

  dashboard_rows <- list()

  combos <- anomalies_df %>%
    distinct(station, variable, season)

  for (i in seq_len(nrow(combos))) {
    stn <- combos$station[i]
    var <- combos$variable[i]
    ssn <- combos$season[i]

    # Current year anomaly
    anom_sub <- anomalies_df %>%
      filter(station == stn, variable == var, season == ssn)
    current_year <- max(anom_sub$year)
    current_anom <- anom_sub %>% filter(year == current_year)

    # Current fitted value
    pred_sub <- seasonal_preds %>%
      filter(station == stn, variable == var, season == ssn, year == current_year)
    current_value <- if (nrow(pred_sub) > 0) pred_sub$fit_natural[1] else NA_real_

    # Status: + / - / 0 based on sign and CI crossing zero
    status <- if (!is.na(current_anom$anomaly_low[1]) && !is.na(current_anom$anomaly_high[1])) {
      if (current_anom$anomaly_low[1] > 0) "+"
      else if (current_anom$anomaly_high[1] < 0) "-"
      else "0"
    } else {
      # Fallback for zscore method (no CI)
      if (current_anom$anomaly[1] > 0) "+" else if (current_anom$anomaly[1] < 0) "-" else "0"
    }

    # Trend over configurable window (from station config or function default)
    cfg <- station_config[[stn]]
    tw <- if (!is.null(cfg$trend_window_years)) cfg$trend_window_years else trend_window_years
    trend_years <- seq(current_year - tw + 1, current_year)
    trend_data <- seasonal_preds %>%
      filter(station == stn, variable == var, season == ssn, year %in% trend_years)

    trend_slope <- NA_real_
    trend_p <- NA_real_
    trend_direction <- "flat"

    min_trend_obs <- max(3, ceiling(tw / 2))
    if (nrow(trend_data) >= min_trend_obs) {
      lm_fit <- lm(fit_natural ~ year, data = trend_data)
      trend_slope <- round(coef(lm_fit)[2], 6)
      trend_p <- round(summary(lm_fit)$coefficients[2, 4], 6)
      trend_direction <- if (trend_p < 0.05) {
        if (trend_slope > 0) "up" else "down"
      } else {
        "flat"
      }
    }

    dashboard_rows[[paste(stn, var, ssn)]] <- data.frame(
      station         = stn,
      variable        = var,
      season          = ssn,
      current_year    = current_year,
      current_value   = round(current_value, 4),
      current_anomaly = current_anom$anomaly[1],
      current_z       = current_anom$z_score[1],
      status          = status,
      trend_slope     = trend_slope,
      trend_p         = trend_p,
      trend_direction = trend_direction,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, dashboard_rows)
}

# =============================================================================
# sanity_check_anomalies()
#
# Verifies that baseline-year anomalies average to approximately zero for
# each station × variable × season. Reports violations.
#
# Parameters:
#   anomalies_df — output of compute_all_anomalies()
#   tolerance    — maximum acceptable |mean anomaly| for baseline years
#
# Returns: data frame of check results (invisible)
# =============================================================================

sanity_check_anomalies <- function(anomalies_df, tolerance = 0.5) {
  cat("\n  Sanity check: baseline-year anomalies should average ~zero\n")

  checks <- anomalies_df %>%
    group_by(station, variable, season) %>%
    summarise(
      method = first(method_used),
      .groups = "drop"
    )

  results <- list()
  any_fail <- FALSE

  for (i in seq_len(nrow(checks))) {
    stn <- checks$station[i]
    var <- checks$variable[i]
    ssn <- checks$season[i]

    cfg <- station_config[[stn]]
    ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])

    ref_anom <- anomalies_df %>%
      filter(station == stn, variable == var, season == ssn,
             year %in% ref_years)

    if (nrow(ref_anom) == 0) next

    mean_anom <- mean(ref_anom$anomaly, na.rm = TRUE)

    # Baseline-year anomalies should average to ~zero on the natural scale
    pass <- abs(mean_anom) < tolerance

    status <- if (pass) "PASS" else "FAIL"
    if (!pass) any_fail <- TRUE

    cat(sprintf("    %s %s %-8s mean_anom = %10.4f  [%s]\n",
                stn, var, ssn, mean_anom, status))

    results[[paste(stn, var, ssn)]] <- data.frame(
      station = stn, variable = var, season = ssn,
      mean_baseline_anomaly = round(mean_anom, 6),
      pass = pass,
      stringsAsFactors = FALSE
    )
  }

  result_df <- do.call(rbind, results)
  if (any_fail) {
    cat("\n  WARNING: Some baseline anomaly checks failed. Review results above.\n")
  } else {
    cat("\n  All baseline anomaly checks passed.\n")
  }
  invisible(result_df)
}

# =============================================================================
# compute_reference_curve()
#
# Builds a 365-point reference-period "normal" curve from a phenology GAM.
# Predicts at DOY 1:365 for each reference year, then averages across years
# on the natural scale (squared for sqrt-transformed models).
#
# Parameters:
#   model           — phenology GAM (cyclic DOY spline + year)
#   reference_years — integer vector of baseline years
#   is_sqrt         — TRUE if model uses sqrt transform (CI, DW)
#
# Returns: numeric vector of length 365 (natural-scale reference values)
# =============================================================================

compute_reference_curve <- function(model, reference_years, is_sqrt = FALSE) {
  # Predict at DOY 1:365 for each reference year
  grid <- expand.grid(day_of_year = 1:365, year = reference_years)
  fits <- predict(model, newdata = grid, type = "response")

  # Reshape to matrix: 365 rows x n_ref_years cols
  fit_matrix <- matrix(fits, nrow = 365, ncol = length(reference_years))

  if (is_sqrt) {
    fit_matrix <- fit_matrix^2
  }

  # Average across reference years for each DOY
  rowMeans(fit_matrix)
}

# =============================================================================
# enrich_prepared_data()
#
# Adds reference_difference_CI and reference_difference_DW columns to the
# prepared data by subtracting the phenology GAM reference curve from each
# raw observation. Writes enriched CSV.
#
# Parameters:
#   fit_result    — output of fit_sentinel_gams()
#   prepared_dir  — directory containing prepared CSVs
#   output_dir    — directory for enriched CSVs
#
# Returns: enriched data frame (invisible)
# =============================================================================

enrich_prepared_data <- function(fit_result, prepared_dir = file.path("data", "sentinel", "prepared"),
                                 output_dir = file.path("data", "sentinel", "prepared")) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  models <- fit_result$models
  ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])

  # Read the original prepared CSV (not the sqrt-transformed model data)
  prep_path <- file.path(prepared_dir, paste0(station_id, "_prepared.csv"))
  data <- read.csv(prep_path, stringsAsFactors = FALSE)
  data$DATE <- as.Date(data$DATE)

  for (var in c("CI", "DW")) {
    mkey <- paste0("phenology_", var)
    pred_col <- paste0("reference_prediction_", var)
    diff_col <- paste0("reference_difference_", var)

    if (!mkey %in% names(models)) {
      data[[pred_col]] <- NA_real_
      data[[diff_col]] <- NA_real_
      next
    }

    is_sqrt <- TRUE  # Both CI and DW are sqrt-transformed
    ref_curve <- compute_reference_curve(models[[mkey]], ref_years, is_sqrt)

    # Look up reference value for each observation's DOY
    doy_idx <- pmin(pmax(data$day_of_year, 1), 365)
    ref_vals <- ref_curve[doy_idx]

    data[[pred_col]] <- ref_vals
    data[[diff_col]] <- data[[var]] - ref_vals
  }

  out_path <- file.path(output_dir, paste0(station_id, "_prepared_enriched.csv"))
  write.csv(data, out_path, row.names = FALSE)
  cat("  Wrote enriched data:", out_path,
      "(", nrow(data), "rows,",
      sum(!is.na(data$reference_difference_CI)), "CI diffs,",
      sum(!is.na(data$reference_difference_DW)), "DW diffs )\n")

  invisible(data)
}
