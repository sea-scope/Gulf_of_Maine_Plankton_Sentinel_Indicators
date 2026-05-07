# =============================================================================
# Sentinel Indicators — Anomaly Bar Chart Plots
#
# Produces one PNG per station x variable x season. Bar chart with error bars,
# colored by significance (gray = not significant, cornflowerblue = significant
# positive, firebrick = significant negative). Jittered raw observation
# anomalies overlaid from the enriched prepared data.
#
# Y-axis limits are set from the anomaly bar/error bar range. Raw points that
# fall outside these limits are clamped to the axis edge, shown as red
# triangles, and labeled with their actual value.
#
# Naming convention: plots/sentinel/{station}/{station}_{variable}_anomaly_bar_{season}.png
# =============================================================================

library(ggplot2)
library(dplyr)

source(file.path("R", "shared", "theme_sentinel.R"))

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# plot_all_anomaly_bars()
#
# Generates individual anomaly bar chart PNGs for CI and DW per season.
#
# Parameters:
#   fit_result   — output of fit_sentinel_gams()
#   anomalies_df — anomalies_long data frame (all stations)
#   output_dir   — base plots directory (default: plots/sentinel)
#   pad_frac     — fractional padding beyond anomaly range for y-axis (default: 0.15)
#
# Returns: character vector of saved file paths (invisible)
# =============================================================================

plot_all_anomaly_bars <- function(
    fit_result,
    anomalies_df,
    output_dir = file.path("plots", "sentinel"),
    pad_frac = 1.0
) {
  station_id <- fit_result$station_id
  cfg <- fit_result$config
  stn_dir <- file.path(output_dir, station_id)
  dir.create(stn_dir, recursive = TRUE, showWarnings = FALSE)

  seasons <- names(cfg$season_boundaries)
  ref_years <- seq(cfg$reference_period[1], cfg$reference_period[2])
  ref_label <- paste0("Reference: ", cfg$reference_period[1], "-",
                       cfg$reference_period[2], " (n = ", length(ref_years), ")")

  # Load enriched prepared data for jittered raw points
  enriched_file <- file.path("data", "sentinel", "prepared",
                              paste0(station_id, "_prepared_enriched.csv"))
  enriched_df <- NULL
  if (file.exists(enriched_file)) {
    enriched_df <- read.csv(enriched_file, stringsAsFactors = FALSE)
  }

  stn_anom <- anomalies_df %>% filter(station == station_id)

  saved <- character(0)

  for (var in c("CI", "DW")) {
    al <- sentinel_anomaly_labels[[var]]

    # Determine which enriched column has the raw anomaly
    diff_col <- paste0("reference_difference_", var)

    for (ssn in seasons) {
      anom_sub <- stn_anom %>%
        filter(variable == var, season == ssn)

      if (nrow(anom_sub) == 0) next

      # Determine significance-based bar color:
      # CI doesn't cross zero => significant
      anom_sub <- anom_sub %>%
        mutate(
          sig = ifelse(anomaly_low > 0, "pos",
                       ifelse(anomaly_high < 0, "neg", "ns")),
          bar_color = case_when(
            sig == "pos" ~ "cornflowerblue",
            sig == "neg" ~ "firebrick",
            TRUE         ~ "gray60"
          )
        )

      # Get raw observation anomalies for jitter
      raw_points <- NULL
      if (!is.null(enriched_df) && diff_col %in% names(enriched_df)) {
        raw_points <- enriched_df %>%
          filter(season == ssn) %>%
          dplyr::select(year, value = !!sym(diff_col)) %>%
          filter(!is.na(value))
      }

      # --- Compute y-axis limits from anomaly bars + error bars ---
      # Pad by 50% of anomaly range OR extend to raw data range, whichever is smaller
      y_data_min <- min(c(anom_sub$anomaly, anom_sub$anomaly_low), na.rm = TRUE)
      y_data_max <- max(c(anom_sub$anomaly, anom_sub$anomaly_high), na.rm = TRUE)
      y_range <- y_data_max - y_data_min
      pad_lo <- pad_frac * y_range
      pad_hi <- pad_frac * y_range
      # If raw points exist, cap padding at the raw data extent
      if (!is.null(raw_points) && nrow(raw_points) > 0) {
        raw_min <- min(raw_points$value, na.rm = TRUE)
        raw_max <- max(raw_points$value, na.rm = TRUE)
        pad_lo <- min(pad_lo, max(0, y_data_min - raw_min))
        pad_hi <- min(pad_hi, max(0, raw_max - y_data_max))
      }
      # Ensure zero is always visible
      y_lim_lo <- min(0, y_data_min) - pad_lo
      y_lim_hi <- max(0, y_data_max) + pad_hi

      # --- Split raw points into inliers and outliers ---
      raw_inliers <- NULL
      raw_outliers <- NULL
      if (!is.null(raw_points) && nrow(raw_points) > 0) {
        raw_points <- raw_points %>%
          mutate(is_outlier = value < y_lim_lo | value > y_lim_hi)
        raw_inliers <- raw_points %>% filter(!is_outlier)
        raw_outliers <- raw_points %>%
          filter(is_outlier) %>%
          mutate(
            actual_value = value,
            # Clamp to axis edge
            value_clamped = pmin(pmax(value, y_lim_lo), y_lim_hi),
            # Format label: round to nearest integer for CI, 1 decimal for DW
            label = if (var == "DW") {
              formatC(round(actual_value, 1), format = "f", digits = 1)
            } else {
              formatC(round(actual_value, 0), format = "f", digits = 0, big.mark = ",")
            }
          )
      }

      # Build plot
      year_start <- cfg$year_start
      max_year <- max(anom_sub$year)

      p <- ggplot(anom_sub, aes(x = year, y = anomaly)) +
        # Zero reference line
        geom_hline(yintercept = 0, linetype = "dashed", color = "grey40",
                   linewidth = 0.5) +
        # Bars colored by significance
        geom_col(aes(fill = sig), width = 0.7, color = NA) +
        scale_fill_manual(
          name = NULL,
          values = c("pos" = "cornflowerblue", "neg" = "firebrick", "ns" = "gray60"),
          labels = c("pos" = "Significant (+)", "neg" = "Significant (-)",
                     "ns" = "Not significant"),
          breaks = c("ns", "pos", "neg")
        ) +
        # Error bars (95% CI)
        geom_errorbar(aes(ymin = anomaly_low, ymax = anomaly_high),
                      width = 0.3, linewidth = 0.4, color = "grey30")

      # Add jittered inlier raw points
      if (!is.null(raw_inliers) && nrow(raw_inliers) > 0) {
        p <- p +
          geom_jitter(data = raw_inliers, aes(x = year, y = value),
                      inherit.aes = FALSE,
                      width = 0.2, height = 0,
                      size = 1, alpha = 0.5, color = "grey20",
                      shape = 16)
      }

      # Add clamped outlier points as red triangles with value labels
      if (!is.null(raw_outliers) && nrow(raw_outliers) > 0) {
        # Add small jitter to x for outliers too
        set.seed(42)
        raw_outliers$x_jit <- raw_outliers$year + runif(nrow(raw_outliers), -0.2, 0.2)
        p <- p +
          geom_point(data = raw_outliers,
                     aes(x = x_jit, y = value_clamped),
                     inherit.aes = FALSE,
                     shape = 17, size = 2, color = "gold") +
          geom_text(data = raw_outliers,
                    aes(x = x_jit, y = value_clamped, label = label),
                    inherit.aes = FALSE,
                    size = 1.8, color = "black",
                    hjust = -0.2, vjust = 0.5, check_overlap = TRUE)
      }

      # Title: e.g. "WBTS, Spring - Calanus Abundance Index Anomaly"
      plot_title <- paste0(station_id, ", ", tools::toTitleCase(ssn),
                           " - ", al$title_suffix)

      p <- p +
        labs(title = plot_title,
             x = NULL,
             y = al$y_lab,
             caption = ref_label) +
        scale_x_continuous(breaks = seq(year_start, max_year, by = 2)) +
        coord_cartesian(xlim = c(year_start - 0.5, max_year + 0.5),
                        ylim = c(y_lim_lo, y_lim_hi)) +
        theme_anomaly() +
        theme(
          plot.title = element_text(size = 12, face = "bold"),
          axis.title = element_text(size = 10),
          axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
          plot.caption = element_text(size = 8, color = "grey40", vjust = 10,
                                      margin = margin(t = 2, b = -10))
        )

      p <- p +
        theme(legend.position = "bottom",
              legend.text = element_text(size = 8))

      fname <- file.path(stn_dir,
                          paste0(station_id, "_", var, "_anomaly_bar_", ssn, ".png"))
      ggsave(fname, plot = p, bg = "white",
             width = 8, height = 5, dpi = 300)
      cat("  Saved:", fname, "\n")
      saved <- c(saved, fname)
    }
  }

  invisible(saved)
}
