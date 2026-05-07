# =============================================================================
# Sentinel Indicators — Analysis Orchestrator
#
# Runs the full analysis pipeline for all stations:
#   1. Fit GAMs (phenology + seasonal) for each station
#   2. Generate predictions (phenology and seasonal)
#   3. Compute baselines
#   4. Save diagnostic plots (partial effects + DHARMa)
#   5. Write summary CSVs
#
# This script is sourced by run_sentinel.R (Step 4).
# =============================================================================

library(mgcv)
library(dplyr)
library(DHARMa)
library(ggplot2)
library(gridExtra)

# Source component scripts
source(file.path("R", "02_sentinel_indicators", "station_config.R"))
source(file.path("R", "02_sentinel_indicators", "fit_sentinel_gams.R"))
source(file.path("R", "02_sentinel_indicators", "compute_anomalies.R"))
source(file.path("R", "02_sentinel_indicators", "plot_phenology.R"))
source(file.path("R", "02_sentinel_indicators", "plot_seasonal_trends.R"))
source(file.path("R", "02_sentinel_indicators", "plot_anomaly_timeseries.R"))
source(file.path("R", "02_sentinel_indicators", "plot_anomaly_bars.R"))
source(file.path("R", "02_sentinel_indicators", "export_sentinel_metadata.R"))

# =============================================================================
# analyze_all_stations()
#
# Main entry point. Iterates over stations, fits GAMs, generates predictions,
# saves diagnostics and plots.
#
# Parameters:
#   stations    — character vector of station IDs (default: all in config)
#   output_dir  — base directory for output CSVs
#   plot_dir    — base directory for diagnostic plots
#
# Returns: list of fit results (one per station), invisibly
# =============================================================================

analyze_all_stations <- function(
    stations   = names(station_config),
    output_dir = file.path("summaries", "sentinel"),
    plot_dir   = file.path("plots", "sentinel")
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  all_fit_results <- list()
  all_diagnostics <- list()
  all_predictions_long <- list()
  all_predictions_wide <- list()
  all_baselines <- list()

  for (stn in stations) {
    cat("\n", strrep("=", 60), "\n")
    cat("ANALYZING STATION:", stn, "\n")
    cat(strrep("=", 60), "\n\n")

    # --- Step 1: Fit GAMs ---
    fit_result <- fit_sentinel_gams(stn)
    all_fit_results[[stn]] <- fit_result

    # --- Step 2: Save diagnostic plots ---
    cat("\n  Saving diagnostic plots...\n")
    save_gam_diagnostic_plots(fit_result, output_dir = plot_dir)

    # --- Step 3: Save phenology and seasonal trend plots ---
    cat("\n  Saving phenology plots...\n")
    plot_all_phenology(fit_result, output_dir = plot_dir)
    cat("\n  Saving seasonal trend plots...\n")
    plot_all_seasonal_trends(fit_result, output_dir = plot_dir)

    # --- Step 4: Generate predictions and baselines ---
    cat("\n  Generating predictions and baselines...\n")
    pred_result <- generate_all_predictions(fit_result)

    all_diagnostics[[stn]] <- fit_result$diagnostics
    all_predictions_long[[stn]] <- pred_result$long
    if (!is.null(pred_result$wide)) all_predictions_wide[[stn]] <- pred_result$wide
    all_baselines[[stn]] <- pred_result$baselines

    # --- Step 4b: Enrich prepared data with reference differences ---
    cat("\n  Enriching prepared data with reference differences...\n")
    enrich_prepared_data(fit_result)
  }

  # --- Combine and write prediction/baseline CSVs ---
  cat("\n", strrep("=", 60), "\n")
  cat("WRITING SUMMARY CSVs\n")
  cat(strrep("=", 60), "\n\n")

  diag_df <- do.call(rbind, all_diagnostics)
  write.csv(diag_df, file.path(output_dir, "model_diagnostics.csv"), row.names = FALSE)
  cat("  Wrote", nrow(diag_df), "rows to model_diagnostics.csv\n")

  pred_long_df <- do.call(rbind, all_predictions_long)
  write.csv(pred_long_df, file.path(output_dir, "predictions_long.csv"), row.names = FALSE)
  cat("  Wrote", nrow(pred_long_df), "rows to predictions_long.csv\n")

  if (length(all_predictions_wide) > 0) {
    # Stations have different seasons (WBTS: 4, CMTS: 3) so columns differ.
    # Use dplyr::bind_rows to fill missing columns with NA.
    pred_wide_df <- dplyr::bind_rows(all_predictions_wide)
    write.csv(pred_wide_df, file.path(output_dir, "predictions_wide.csv"), row.names = FALSE)
    cat("  Wrote", nrow(pred_wide_df), "rows to predictions_wide.csv\n")
  }

  baseline_df <- do.call(rbind, all_baselines)
  write.csv(baseline_df, file.path(output_dir, "baselines.csv"), row.names = FALSE)
  cat("  Wrote", nrow(baseline_df), "rows to baselines.csv\n")

  # --- Step 5: Compute anomalies (CI and DW only, CSI excluded) ---
  cat("\n", strrep("=", 60), "\n")
  cat("COMPUTING ANOMALIES\n")
  cat(strrep("=", 60), "\n\n")

  anomalies_df <- compute_all_anomalies(all_fit_results)
  write.csv(anomalies_df, file.path(output_dir, "anomalies_long.csv"), row.names = FALSE)
  cat("  Wrote", nrow(anomalies_df), "rows to anomalies_long.csv\n")

  # Log methods used
  method_summary <- anomalies_df %>%
    group_by(station, variable, season, method_used) %>%
    summarise(n = n(), .groups = "drop")
  cat("\n  Uncertainty methods used:\n")
  for (i in seq_len(nrow(method_summary))) {
    cat(sprintf("    %s %s %-8s -> %s (%d years)\n",
                method_summary$station[i], method_summary$variable[i],
                method_summary$season[i], method_summary$method_used[i],
                method_summary$n[i]))
  }

  # --- Step 6: Sanity check ---
  sanity_check_anomalies(anomalies_df)

  # --- Step 6b: Anomaly time series plots ---
  cat("\n", strrep("=", 60), "\n")
  cat("GENERATING ANOMALY PLOTS\n")
  cat(strrep("=", 60), "\n\n")

  for (stn in stations) {
    cat("  Plotting anomalies for", stn, "...\n")
    plot_all_anomaly_timeseries(all_fit_results[[stn]], anomalies_df,
                                output_dir = plot_dir)
    cat("  Plotting anomaly bar charts for", stn, "...\n")
    plot_all_anomaly_bars(all_fit_results[[stn]], anomalies_df,
                          output_dir = plot_dir)
  }

  # --- Step 7: Build dashboard CSV ---
  cat("\n", strrep("=", 60), "\n")
  cat("BUILDING DASHBOARD\n")
  cat(strrep("=", 60), "\n\n")

  dashboard_df <- build_dashboard(anomalies_df, pred_long_df, baseline_df)
  write.csv(dashboard_df, file.path(output_dir, "sentinel_dashboard.csv"), row.names = FALSE)
  cat("  Wrote", nrow(dashboard_df), "rows to sentinel_dashboard.csv\n")

  # Print dashboard summary
  cat("\n  Dashboard summary:\n")
  for (i in seq_len(nrow(dashboard_df))) {
    cat(sprintf("    %s %s %-8s  value=%10.2f  anomaly=%10.2f  z=%6.2f  status=%s  trend=%s\n",
                dashboard_df$station[i], dashboard_df$variable[i],
                dashboard_df$season[i], dashboard_df$current_value[i],
                dashboard_df$current_anomaly[i], dashboard_df$current_z[i],
                dashboard_df$status[i], dashboard_df$trend_direction[i]))
  }

  # --- Step 8: Export sentinel metadata JSON ---
  cat("\n", strrep("=", 60), "\n")
  cat("EXPORTING METADATA\n")
  cat(strrep("=", 60), "\n\n")

  export_sentinel_metadata(plot_dir = plot_dir, stations = stations)

  cat("\nAnalysis complete.\n")
  invisible(all_fit_results)
}

