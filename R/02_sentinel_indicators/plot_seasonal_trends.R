# =============================================================================
# Sentinel Indicators — Seasonal Trend Plots
#
# Produces one multi-panel seasonal trend PNG per station x variable:
# 2x2 grid (4 seasons) or 1x3 row (3 seasons), year on x-axis, fitted
# seasonal GAM line with 95% CI ribbon (when s(year) is significant),
# raw points overlaid with season-specific colors.
#
# Naming convention: plots/sentinel/{station}/{station}_{variable}_seasonal.png
# =============================================================================

library(ggplot2)
library(dplyr)
library(gridExtra)

source(file.path("R", "shared", "theme_sentinel.R"))

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}
if (!exists("predict_seasonal")) {
  source(file.path("R", "02_sentinel_indicators", "compute_anomalies.R"))
}

# =============================================================================
# plot_all_seasonal_trends()
#
# Generates seasonal trend PNGs for all variables of a station.
#
# Parameters:
#   fit_result — output of fit_sentinel_gams()
#   output_dir — base plots directory (default: plots/sentinel)
#
# Returns: character vector of saved file paths (invisible)
# =============================================================================

plot_all_seasonal_trends <- function(
    fit_result,
    output_dir = file.path("plots", "sentinel")
) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  models <- fit_result$models
  stn_dir <- file.path(output_dir, station_id)
  dir.create(stn_dir, recursive = TRUE, showWarnings = FALSE)

  seasons <- names(cfg$season_boundaries)
  all_years <- sort(unique(c(
    fit_result$data$ci_data$year,
    fit_result$data$csi_data$year,
    fit_result$data$dw_data$year
  )))
  year_range <- seq(min(all_years), max(all_years))
  max_year <- max(all_years)

  saved <- character(0)

  for (var in c("CI", "CSI", "DW")) {
    vl <- sentinel_var_labels[[var]]
    plots_list <- list()

    for (ssn in seasons) {
      mkey <- paste0(ssn, "_", var)
      sdata <- fit_result$data$seasonal[[paste0(ssn, "_", var)]]
      if (is.null(sdata) || nrow(sdata) == 0) next

      # Check if s(year) is significant — only show trend line if so
      show_trend <- FALSE
      if (mkey %in% names(models)) {
        s <- summary(models[[mkey]])
        year_row <- grep("^s\\(year", rownames(s$s.table))
        if (length(year_row) > 0) {
          year_pval <- s$s.table[year_row[1], "p-value"]
          show_trend <- !is.na(year_pval) && year_pval < 0.05
        }
      }

      p <- ggplot()

      if (show_trend && mkey %in% names(models)) {
        doy_varname <- "day_of_year"
        doy_val <- get_mid_season_doy(station_id, ssn)

        if (cfg$n_seasons == 3 && ssn == "winter") {
          doy_varname <- "day_of_year_adj"
          doy_val <- mid_season_doy_adj[["CMTS"]][["winter"]]
        }

        preds <- predict_seasonal(models[[mkey]], year_range, doy_val, doy_varname)

        p <- p +
          geom_ribbon(data = preds, aes(x = year, ymin = fit_low, ymax = fit_high),
                      fill = sentinel_season_colors[[ssn]], alpha = 0.2) +
          geom_line(data = preds, aes(x = year, y = fit), color = "black")
      }

      p <- p +
        geom_point(data = sdata, aes(x = year, y = .data[[var]]),
                   color = sentinel_season_colors[[ssn]], size = 2) +
        labs(title = tools::toTitleCase(ssn), x = "", y = "") +
        theme_seasonal()

      # Add y-axis label to first plot
      if (length(plots_list) == 0) {
        p <- p + labs(y = vl$y_lab)
      }

      # Add sqrt scale if needed
      if (!is.null(vl$sqrt_breaks)) {
        p <- p + scale_y_continuous(breaks = vl$sqrt_breaks, labels = vl$sqrt_labels)
      }

      # Set x limits
      year_start <- cfg$year_start
      p <- p + scale_x_continuous(
        breaks = seq(year_start, max_year, by = 4),
        limits = c(year_start, max_year + 1)
      )

      plots_list[[ssn]] <- p
    }

    if (length(plots_list) == 0) next

    n_seasons <- length(plots_list)
    if (n_seasons == 4) {
      grid_plot <- gridExtra::grid.arrange(
        grobs = plots_list, nrow = 2, ncol = 2,
        top = paste0(station_id, ", ", vl$title_suffix, " - Seasonal Trends"))
      plot_width <- 10; plot_height <- 8
    } else {
      grid_plot <- gridExtra::grid.arrange(
        grobs = plots_list, nrow = 1, ncol = n_seasons,
        top = paste0(station_id, ", ", vl$title_suffix, " - Seasonal Trends"))
      plot_width <- 10; plot_height <- 6
    }

    fname <- file.path(stn_dir, paste0(station_id, "_", var, "_seasonal.png"))
    ggsave(fname, plot = grid_plot, bg = "white",
           width = plot_width, height = plot_height, dpi = 300)
    cat("  Saved:", fname, "\n")
    saved <- c(saved, fname)
  }

  invisible(saved)
}
