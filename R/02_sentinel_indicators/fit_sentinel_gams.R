# =============================================================================
# Sentinel Indicators — GAM Fitting Layer
#
# Fits phenology GAMs (full-year cyclic) and seasonal GAMs (per-season cubic
# regression) for each station x variable combination. Returns model objects
# and diagnostic summaries.
#
# GAM specifications preserved from reference scripts:
#   Phenology:  variable ~ s(day_of_year, bs = "cc") + s(year), method = "REML"
#   Seasonal:   variable ~ s(day_of_year, bs = "cr") + s(year, k = 4), method = "REML"
#               (CMTS winter uses k = 3 and day_of_year_adj for continuity)
#
# Transforms: CI and DW are sqrt-transformed before fitting. CSI is not.
# =============================================================================

library(mgcv)
library(dplyr)
library(DHARMa)

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# fit_sentinel_gams()
#
# Fits all GAMs for one station: phenology + seasonal, for CI/CSI/DW.
#
# Parameters:
#   station_id   — "WBTS" or "CMTS"
#   prepared_dir — directory containing prepared CSVs
#
# Returns: a list with components:
#   $models      — named list of gam objects (e.g., "phenology_CI", "spring_CI")
#   $diagnostics — data frame with one row per model
#   $data        — list of transformed data frames (ci_data, csi_data, dw_data)
#                  plus seasonal subsets
# =============================================================================

fit_sentinel_gams <- function(
    station_id,
    prepared_dir = file.path("data", "sentinel", "prepared")
) {
  cfg <- station_config[[station_id]]
  if (is.null(cfg)) stop("Unknown station_id: ", station_id)

  # ---------------------------------------------------------------------------
  # Read prepared data
  # ---------------------------------------------------------------------------
  prep_path <- file.path(prepared_dir, paste0(station_id, "_prepared.csv"))
  if (!file.exists(prep_path)) stop("Prepared CSV not found: ", prep_path)

  data <- read.csv(prep_path, stringsAsFactors = FALSE)
  data$DATE <- as.Date(data$DATE)
  cat("Fitting GAMs for", station_id, "—", nrow(data), "rows\n")

  # ---------------------------------------------------------------------------
  # Prepare variable-specific datasets with transforms
  # ---------------------------------------------------------------------------
  ci_data <- data %>%
    filter(!is.na(CI), CI > 0) %>%
    mutate(CI = sqrt(CI))

  csi_data <- data %>%
    filter(!is.na(CSI))

  dw_data <- data %>%
    filter(!is.na(DW), DW > 0) %>%
    mutate(DW = sqrt(DW))

  # ---------------------------------------------------------------------------
  # CMTS-specific: DW outlier detection (from reference script)
  # ---------------------------------------------------------------------------
  if (station_id == "CMTS" && nrow(dw_data) > 10) {
    dw_gam_prelim <- gam(DW ~ s(day_of_year, bs = "cc") + s(year),
                         data = dw_data, method = "REML")
    dw_resid <- simulateResiduals(fittedModel = dw_gam_prelim, n = 1000)
    outlier_idx <- which(dw_resid$scaledResiduals < 0.001 |
                           dw_resid$scaledResiduals > 0.999)
    if (length(outlier_idx) > 0) {
      cat("  DW outliers removed:", length(outlier_idx), "observations\n")
      dw_data <- dw_data[-outlier_idx, ]
    }
  }

  # ---------------------------------------------------------------------------
  # CMTS-specific: adjust winter DOY for continuity
  # (Jan-Mar DOY 1-73 becomes 366-438 so winter is contiguous)
  # ---------------------------------------------------------------------------
  if (cfg$n_seasons == 3) {
    adjust_winter_doy <- function(df) {
      df$day_of_year_adj <- df$day_of_year
      winter_early <- which(df$season == "winter" & df$day_of_year < 100)
      df$day_of_year_adj[winter_early] <- df$day_of_year[winter_early] + 365
      return(df)
    }
    ci_data  <- adjust_winter_doy(ci_data)
    csi_data <- adjust_winter_doy(csi_data)
    dw_data  <- adjust_winter_doy(dw_data)
  }

  # ---------------------------------------------------------------------------
  # Create seasonal subsets
  # ---------------------------------------------------------------------------
  seasons <- names(cfg$season_boundaries)
  seasonal_data <- list()

  for (var in c("CI", "CSI", "DW")) {
    var_df <- switch(var, CI = ci_data, CSI = csi_data, DW = dw_data)
    for (ssn in seasons) {
      key <- paste0(ssn, "_", var)
      seasonal_data[[key]] <- var_df %>% filter(season == ssn)
    }
  }

  # ---------------------------------------------------------------------------
  # Fit phenology GAMs (cyclic spline over full year)
  # ---------------------------------------------------------------------------
  models <- list()
  diag_rows <- list()
  dharma_resids <- list()

  cat("  Fitting phenology GAMs...\n")
  for (var in c("CI", "CSI", "DW")) {
    var_df <- switch(var, CI = ci_data, CSI = csi_data, DW = dw_data)
    if (nrow(var_df) < 10) {
      cat("    Skipping phenology", var, "— too few observations (", nrow(var_df), ")\n")
      next
    }
    fml <- as.formula(paste0(var, " ~ s(day_of_year, bs = 'cc') + s(year)"))
    model_name <- paste0("phenology_", var)
    tryCatch({
      m <- gam(fml, data = var_df, method = "REML")
      models[[model_name]] <- m
      diag_result <- extract_diagnostics(m, station_id, var, "phenology")
      diag_rows[[model_name]] <- diag_result$diagnostics
      dharma_resids[[model_name]] <- diag_result$dharma_resid
      cat("    ", model_name, "— OK\n")
    }, error = function(e) {
      cat("    ", model_name, "— FAILED:", conditionMessage(e), "\n")
    })
  }

  # ---------------------------------------------------------------------------
  # Fit seasonal GAMs
  # ---------------------------------------------------------------------------
  cat("  Fitting seasonal GAMs...\n")
  for (var in c("CI", "CSI", "DW")) {
    for (ssn in seasons) {
      key <- paste0(ssn, "_", var)
      sdata <- seasonal_data[[key]]
      if (is.null(sdata) || nrow(sdata) < 8) {
        cat("    Skipping", key, "— too few observations (", nrow(sdata), ")\n")
        next
      }

      # Determine DOY variable and year k
      doy_var <- "day_of_year"
      year_k <- 4
      if (cfg$n_seasons == 3 && ssn == "winter") {
        doy_var <- "day_of_year_adj"
        year_k <- 3
      }

      # Ensure k for year doesn't exceed unique years
      n_unique_years <- length(unique(sdata$year))
      year_k <- min(year_k, n_unique_years - 1)
      if (year_k < 2) year_k <- 2

      fml <- as.formula(paste0(var, " ~ s(", doy_var, ", bs = 'cr') + s(year, k = ", year_k, ")"))
      model_name <- key

      tryCatch({
        m <- gam(fml, data = sdata, method = "REML")
        models[[model_name]] <- m
        diag_result <- extract_diagnostics(m, station_id, var, ssn)
        diag_rows[[model_name]] <- diag_result$diagnostics
        dharma_resids[[model_name]] <- diag_result$dharma_resid
        cat("    ", model_name, "— OK (n=", nrow(sdata), ")\n")
      }, error = function(e) {
        cat("    ", model_name, "— FAILED:", conditionMessage(e), "\n")
      })
    }
  }

  # ---------------------------------------------------------------------------
  # Combine diagnostics
  # ---------------------------------------------------------------------------
  diagnostics <- do.call(rbind, diag_rows)
  rownames(diagnostics) <- NULL

  cat("  Fitted", length(models), "models for", station_id, "\n")

  return(list(
    models = models,
    diagnostics = diagnostics,
    dharma_resids = dharma_resids,
    data = list(
      ci_data = ci_data,
      csi_data = csi_data,
      dw_data = dw_data,
      seasonal = seasonal_data
    ),
    station_id = station_id,
    config = cfg
  ))
}

# =============================================================================
# extract_diagnostics() — extract GAM summary metrics and DHARMa tests
# =============================================================================

extract_diagnostics <- function(model, station_id, variable, season) {
  s <- summary(model)

  # Extract p-values and edf for each smooth term from s.table
  # Rows are named like "s(day_of_year)", "s(year,k=4)", "s(day_of_year_adj)"
  # Use "^s\\(year" to match s(year...) but NOT s(day_of_year...)
  year_p   <- NA_real_
  year_edf <- NA_real_
  doy_p    <- NA_real_
  doy_edf  <- NA_real_
  if (!is.null(s$s.table)) {
    year_row <- grep("^s\\(year", rownames(s$s.table))
    if (length(year_row) > 0) {
      year_p   <- s$s.table[year_row[1], "p-value"]
      year_edf <- s$s.table[year_row[1], "edf"]
    }
    doy_row <- grep("day_of_year", rownames(s$s.table))
    if (length(doy_row) > 0) {
      doy_p   <- s$s.table[doy_row[1], "p-value"]
      doy_edf <- s$s.table[doy_row[1], "edf"]
    }
  }

  # Scale parameter (residual variance for Gaussian)
  scale_est <- s$scale

  # DHARMa diagnostics (wrapped in tryCatch for robustness)
  # Returns both p-values and the residual object for reuse in diagnostic plots
  dharma_resid <- tryCatch(
    simulateResiduals(fittedModel = model, n = 1000),
    error = function(e) NULL
  )

  dharma_pvals <- if (!is.null(dharma_resid)) {
    list(
      uniformity_p = testUniformity(dharma_resid, plot = FALSE)$p.value,
      outliers_p   = testOutliers(dharma_resid, plot = FALSE)$p.value,
      dispersion_p = testDispersion(dharma_resid, plot = FALSE)$p.value
    )
  } else {
    list(uniformity_p = NA, outliers_p = NA, dispersion_p = NA)
  }

  diag_df <- data.frame(
    station       = station_id,
    variable      = variable,
    season        = season,
    r_sq          = round(s$r.sq, 4),
    dev_expl      = round(s$dev.expl * 100, 2),
    n             = nrow(model$model),
    scale_est     = round(scale_est, 6),
    doy_edf       = round(doy_edf, 2),
    doy_p         = signif(doy_p, 4),
    year_edf      = round(year_edf, 2),
    year_p        = signif(year_p, 4),
    year_sig      = !is.na(year_p) & year_p < 0.05,
    uniformity_p  = round(dharma_pvals$uniformity_p, 4),
    outliers_p    = round(dharma_pvals$outliers_p, 4),
    dispersion_p  = round(dharma_pvals$dispersion_p, 4),
    stringsAsFactors = FALSE
  )

  list(diagnostics = diag_df, dharma_resid = dharma_resid)
}

# =============================================================================
# save_gam_diagnostic_plots() — save partial effect plots and DHARMa diagnostics
#
# Produces two types of output per station:
#   1. Partial effect plots (mgcv::plot.gam) for each model
#   2. DHARMa residual diagnostic plots for each model
# =============================================================================

save_gam_diagnostic_plots <- function(
    fit_result,
    output_dir = file.path("plots", "sentinel")
) {
  station_id <- fit_result$station_id
  models <- fit_result$models
  stn_dir <- file.path(output_dir, station_id, "diagnostics")
  dir.create(stn_dir, recursive = TRUE, showWarnings = FALSE)

  for (model_name in names(models)) {
    m <- models[[model_name]]

    # --- Partial effect plots ---
    pe_file <- file.path(stn_dir, paste0(station_id, "_", model_name, "_partial_effects.png"))
    n_smooth <- length(m$smooth)
    png(pe_file, width = 600 * n_smooth, height = 600, res = 150)
    par(mfrow = c(1, n_smooth), mar = c(5, 5, 4, 2), cex.main = 1.2, cex.lab = 1.1)
    for (i in seq_len(n_smooth)) {
      plot(m, select = i, main = paste0(model_name, ": ", m$smooth[[i]]$label))
    }
    dev.off()
    cat("  Saved:", pe_file, "\n")

    # --- DHARMa diagnostic plot (reuses residuals from extract_diagnostics) ---
    dharma_file <- file.path(stn_dir, paste0(station_id, "_", model_name, "_dharma.png"))
    resid <- fit_result$dharma_resids[[model_name]]
    if (!is.null(resid)) {
      tryCatch({
        png(dharma_file, width = 1200, height = 600, res = 150)
        plot(resid, main = paste0(station_id, " — ", model_name))
        dev.off()
        cat("  Saved:", dharma_file, "\n")
      }, error = function(e) {
        cat("  DHARMa plot FAILED for", model_name, ":", conditionMessage(e), "\n")
      })
    } else {
      cat("  DHARMa plot SKIPPED for", model_name, "(no residuals available)\n")
    }
  }
}
