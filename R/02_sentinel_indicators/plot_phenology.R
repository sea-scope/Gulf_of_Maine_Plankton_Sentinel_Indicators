# =============================================================================
# Sentinel Indicators — Phenology Plots
#
# Produces one phenology PNG per station x variable: day of year on x-axis,
# all years of raw observations overlaid, GAM climatology line and 95% CI
# ribbon, most recent 3 years highlighted with distinct colors/shapes.
#
# Naming convention: plots/sentinel/{station}/{station}_{variable}_phenology.png
# =============================================================================

library(ggplot2)
library(dplyr)

source(file.path("R", "shared", "theme_sentinel.R"))

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}
if (!exists("predict_phenology")) {
  source(file.path("R", "02_sentinel_indicators", "compute_anomalies.R"))
}

# =============================================================================
# plot_all_phenology()
#
# Generates phenology PNGs for all variables of a station.
#
# Parameters:
#   fit_result — output of fit_sentinel_gams()
#   output_dir — base plots directory (default: plots/sentinel)
#
# Returns: character vector of saved file paths (invisible)
# =============================================================================

plot_all_phenology <- function(
    fit_result,
    output_dir = file.path("plots", "sentinel")
) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  models <- fit_result$models
  stn_dir <- file.path(output_dir, station_id)
  dir.create(stn_dir, recursive = TRUE, showWarnings = FALSE)

  # Year range and period aesthetics
  all_years <- sort(unique(c(
    fit_result$data$ci_data$year,
    fit_result$data$csi_data$year,
    fit_result$data$dw_data$year
  )))
  year_range <- seq(min(all_years), max(all_years))
  mid_year <- round(median(year_range))
  ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])
  aes_cfg <- build_year_period_aesthetics(all_years, ref_years)

  saved <- character(0)

  for (var in c("CI", "CSI", "DW")) {
    mkey <- paste0("phenology_", var)
    if (!mkey %in% names(models)) next

    preds <- predict_phenology(models[[mkey]], mid_year)
    var_df <- switch(var,
      CI  = aes_cfg$assign_fn(fit_result$data$ci_data),
      CSI = aes_cfg$assign_fn(fit_result$data$csi_data),
      DW  = aes_cfg$assign_fn(fit_result$data$dw_data)
    )

    vl <- sentinel_var_labels[[var]]

    p <- ggplot() +
      geom_ribbon(data = preds, aes(x = day_of_year, ymin = fit_low, ymax = fit_high),
                  fill = "grey", alpha = 0.4) +
      geom_line(data = preds, aes(x = day_of_year, y = fit), color = "black") +
      geom_point(data = var_df,
                 aes(x = day_of_year, y = .data[[var]],
                     color = year_period, shape = year_period,
                     size = year_period, alpha = year_period)) +
      scale_color_manual(values = aes_cfg$colors, name = NULL) +
      scale_shape_manual(values = aes_cfg$shapes, name = NULL) +
      scale_size_manual(values = aes_cfg$sizes, name = NULL) +
      scale_alpha_manual(values = aes_cfg$alphas, name = NULL) +
      scale_x_continuous(breaks = sentinel_month_breaks,
                         labels = sentinel_month_labels, limits = c(1, 365)) +
      geom_vline(xintercept = sentinel_season_lines, linetype = "dashed",
                 color = "black", linewidth = 1, alpha = 0.3) +
      labs(x = "", y = vl$y_lab,
           title = paste0(station_id, ", ", vl$title_suffix)) +
      theme_phenology()

    if (!is.null(vl$sqrt_breaks)) {
      p <- p + scale_y_continuous(breaks = vl$sqrt_breaks, labels = vl$sqrt_labels)
    }

    if (var %in% c("CSI", "DW")) {
      p <- p + theme(legend.position = c(0.9, 0.05))
    }

    fname <- file.path(stn_dir, paste0(station_id, "_", var, "_phenology.png"))
    ggsave(fname, plot = p, bg = "white", width = 8, height = 6, dpi = 300)
    cat("  Saved:", fname, "\n")
    saved <- c(saved, fname)
  }

  invisible(saved)
}
