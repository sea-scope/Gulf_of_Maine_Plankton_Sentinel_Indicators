# =============================================================================
# Sentinel Indicators — Anomaly Time Series Plots
#
# Produces one multi-panel anomaly time series PNG per station x variable
# (CI and DW only; CSI excluded). 2x2 grid (4 seasons) or 1x3 row (3 seasons).
# Year on x-axis, anomaly bar + 95% CI ribbon, zero reference line, most
# recent 3 years highlighted.
#
# Each panel includes a text annotation showing the reference period.
#
# Naming convention: plots/sentinel/{station}/{station}_{variable}_anomaly.png
# =============================================================================

library(ggplot2)
library(dplyr)
library(gridExtra)

source(file.path("R", "shared", "theme_sentinel.R"))

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# plot_all_anomaly_timeseries()
#
# Generates anomaly time series PNGs for CI and DW for a station.
#
# Parameters:
#   fit_result   — output of fit_sentinel_gams()
#   anomalies_df — anomalies_long data frame (all stations)
#   output_dir   — base plots directory (default: plots/sentinel)
#
# Returns: character vector of saved file paths (invisible)
# =============================================================================

plot_all_anomaly_timeseries <- function(
    fit_result,
    anomalies_df,
    output_dir = file.path("plots", "sentinel")
) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  stn_dir <- file.path(output_dir, station_id)
  dir.create(stn_dir, recursive = TRUE, showWarnings = FALSE)

  seasons <- names(cfg$season_boundaries)
  ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])
  ref_label <- paste0("Reference: ", cfg$reference_period[1], "-",
                       cfg$reference_period[2], " (n = ", length(ref_years), ")")

  # Auto-compute recent 3 years for highlighting
  stn_anom <- anomalies_df %>% filter(station == station_id)
  max_year <- max(stn_anom$year)
  recent_years <- (max_year - 2):max_year

  saved <- character(0)

  for (var in c("CI", "DW")) {
    al <- sentinel_anomaly_labels[[var]]
    plots_list <- list()

    for (ssn in seasons) {
      anom_sub <- stn_anom %>%
        filter(variable == var, season == ssn) %>%
        mutate(
          highlight = ifelse(year %in% recent_years, as.character(year), "other"),
          highlight = factor(highlight,
                             levels = c("other", as.character(recent_years)))
        )

      if (nrow(anom_sub) == 0) next

      # Build color/shape/size for recent-year highlighting
      highlight_colors <- c("other" = "grey50")
      highlight_shapes <- c("other" = 16)
      highlight_sizes  <- c("other" = 2)
      for (i in seq_along(recent_years)) {
        yr_chr <- as.character(recent_years[i])
        highlight_colors[yr_chr] <- c("purple", "orange", "firebrick3")[i]
        highlight_shapes[yr_chr] <- c(18, 8, 15)[i]
        highlight_sizes[yr_chr]  <- c(3, 3.5, 3)[i]
      }

      ssn_color <- sentinel_season_colors[[ssn]]

      p <- ggplot(anom_sub, aes(x = year, y = anomaly)) +
        # 95% CI ribbon
        geom_ribbon(aes(ymin = anomaly_low, ymax = anomaly_high),
                    fill = ssn_color, alpha = 0.2) +
        # Zero reference line
        geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
        # Anomaly line
        geom_line(color = ssn_color, linewidth = 0.5) +
        # Points with recent-year highlighting
        geom_point(aes(color = highlight, shape = highlight, size = highlight)) +
        scale_color_manual(values = highlight_colors, name = NULL,
                           guide = guide_legend(override.aes = list(size = 3))) +
        scale_shape_manual(values = highlight_shapes, name = NULL) +
        scale_size_manual(values = highlight_sizes, name = NULL) +
        # Reference period annotation
        annotate("text", x = min(anom_sub$year) + 1, y = Inf,
                 label = ref_label, hjust = 0, vjust = 1.5,
                 size = 2.5, color = "grey40") +
        labs(title = tools::toTitleCase(ssn), x = "", y = "") +
        theme_anomaly() +
        theme(legend.position = "none")

      # Add y-axis label to first plot
      if (length(plots_list) == 0) {
        p <- p + labs(y = al$y_lab)
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
        top = paste0(station_id, ", ", al$title_suffix))
      plot_width <- 10; plot_height <- 8
    } else {
      grid_plot <- gridExtra::grid.arrange(
        grobs = plots_list, nrow = 1, ncol = n_seasons,
        top = paste0(station_id, ", ", al$title_suffix))
      plot_width <- 10; plot_height <- 6
    }

    fname <- file.path(stn_dir, paste0(station_id, "_", var, "_anomaly.png"))
    ggsave(fname, plot = grid_plot, bg = "white",
           width = plot_width, height = plot_height, dpi = 300)
    cat("  Saved:", fname, "\n")
    saved <- c(saved, fname)
  }

  invisible(saved)
}
