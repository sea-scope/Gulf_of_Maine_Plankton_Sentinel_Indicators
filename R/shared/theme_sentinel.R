# =============================================================================
# Shared Theme and Aesthetics for Sentinel Indicator Plots
#
# Provides consistent visual styling across phenology, seasonal trend, and
# anomaly time series plots. All plotting scripts source this file.
#
# Contents:
#   sentinel_var_labels    — variable display info (y-axis labels, titles, etc.)
#   sentinel_season_colors — per-season color palette
#   sentinel_month_breaks  — DOY → month label mapping
#   build_year_period_aesthetics() — auto-compute period colors/shapes/sizes
#   theme_phenology()      — ggplot theme for phenology plots
#   theme_seasonal()       — ggplot theme for seasonal trend panels
#   theme_anomaly()        — ggplot theme for anomaly time series panels
# =============================================================================

library(ggplot2)

# =============================================================================
# Variable display information
# =============================================================================

sentinel_var_labels <- list(
  CI  = list(
    y_lab = expression(paste("CIII - CVI Abundance (1,000 ", m^{-2}, ")")),
    title_suffix = "Calanus Abundance Index",
    sqrt_breaks = c(100, 200, 300, 400, 500),
    sqrt_labels = c("10", "40", "90", "160", "250")
  ),
  CSI = list(
    y_lab = "Copepodite Stage Index",
    title_suffix = "Calanus Cohort Stage Structure",
    sqrt_breaks = NULL,
    sqrt_labels = NULL
  ),
  DW  = list(
    y_lab = expression("Dry Weight (g/"*m^2*")"),
    title_suffix = "Zooplankton Biomass Index",
    sqrt_breaks = c(1, 2, 3, 4, 5),
    sqrt_labels = c("1", "4", "9", "16", "25")
  )
)

# Anomaly y-axis labels (natural scale, signed)
sentinel_anomaly_labels <- list(
  CI = list(
    y_lab = expression(paste("Anomaly (1,000 ", m^{-2}, ")")),
    title_suffix = "Calanus Abundance Anomaly"
  ),
  DW = list(
    y_lab = expression("Anomaly (g/"*m^2*")"),
    title_suffix = "Zooplankton Biomass Anomaly"
  )
)

# =============================================================================
# Season color palette
# =============================================================================

sentinel_season_colors <- c(
  spring = "seagreen",
  summer = "darkorange",
  fall   = "firebrick",
  winter = "cornflowerblue"
)

# =============================================================================
# Month breaks for DOY x-axis
# =============================================================================

sentinel_month_breaks <- c(1, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 335)
sentinel_month_labels <- month.abb[1:12]
sentinel_season_lines <- c(73.5, 147.5, 247.5, 364.5)

# =============================================================================
# build_year_period_aesthetics()
#
# Auto-computes year_period factor levels, colors, shapes, sizes, and alphas
# from the station config (reference period + recent 3 years).
#
# Parameters:
#   all_years  — sorted integer vector of all years in data
#   ref_years  — integer vector of reference-period years
#
# Returns: list with $levels, $colors, $shapes, $sizes, $alphas,
#          $assign_fn (function to add year_period column to a data frame)
# =============================================================================

build_year_period_aesthetics <- function(all_years, ref_years) {
  max_year <- max(all_years)
  recent_years <- (max_year - 2):max_year

  levels <- c(
    paste0(min(ref_years), " - ", max(ref_years)),
    paste0(max(ref_years) + 1, " - ", min(recent_years) - 1),
    as.character(recent_years)
  )

  colors <- setNames(
    c("seagreen3", "cornflowerblue", "purple", "orange", "firebrick3")[seq_along(levels)],
    levels
  )
  shapes <- setNames(c(16, 17, 18, 8, 15)[seq_along(levels)], levels)
  sizes  <- setNames(c(2, 2, 2.5, 3, 2.5)[seq_along(levels)], levels)
  alphas <- setNames(c(0.6, 0.6, 1, 1, 1)[seq_along(levels)], levels)

  assign_fn <- function(df) {
    df$year_period <- dplyr::case_when(
      df$year %in% ref_years    ~ levels[1],
      df$year %in% recent_years ~ as.character(df$year),
      TRUE                      ~ levels[2]
    )
    df$year_period <- factor(df$year_period, levels = levels)
    df
  }

  list(
    levels  = levels,
    colors  = colors,
    shapes  = shapes,
    sizes   = sizes,
    alphas  = alphas,
    assign_fn = assign_fn
  )
}

# =============================================================================
# Themes
# =============================================================================

theme_phenology <- function() {
  theme_bw() +
    theme(
      axis.text.y = element_text(angle = 90, hjust = 0.5),
      plot.margin = margin(1, 2, 1, 2),
      legend.position = c(0.9, 0.75),
      legend.justification = c(1, 0),
      legend.title = element_blank(),
      legend.text = element_text(size = 8),
      legend.background = element_rect(color = "black", fill = "white", linewidth = 0.5),
      legend.spacing.x = unit(0, "pt"),
      legend.spacing.y = unit(0, "pt"),
      legend.key.width = unit(0.2, "lines"),
      legend.key.height = unit(0.2, "lines")
    )
}

theme_seasonal <- function() {
  theme_minimal() +
    theme(plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "lines"))
}

theme_anomaly <- function() {
  theme_minimal() +
    theme(
      plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "lines"),
      panel.grid.minor = element_blank()
    )
}
