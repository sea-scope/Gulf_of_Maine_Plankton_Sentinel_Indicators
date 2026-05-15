# =============================================================================
# Satellite Products — Climatology Figure Layer
#
# Generates per-polygon satellite climatology PNGs from the master summary CSV
# at summaries/satellite/satellite_summary.csv.
#
# Two figure types per (geography_set, polygon_id, variable) combination:
#
#   1. Overview — all years overlaid, viridis plasma colour scale, ± 1 SD error
#      bars. Sparse windows excluded. One PNG per combo.
#      Output: plots/satellite/{geography_set}/{gset}_{polygon_id}_{var}_overview.png
#
#   2. Per-year climatology — four layers back-to-front:
#        a) Light grey envelope: historical range (max mean + SD, min mean - SD)
#        b) Darker envelope: climatological mean ± 1 SD across years
#        c) Dashed line: climatological mean
#        d) Bold orange line + error bars: focus year
#      One PNG per combo per year.
#      Output: plots/satellite/{geography_set}/{gset}_{polygon_id}_{var}_{year}.png
#
# If the focus year has zero non-sparse rows a placeholder PNG is written.
#
# Input:  summaries/satellite/satellite_summary.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(viridis)
  library(scales)
  library(readr)
})


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# DOY of the first 8-day window for each calendar month (MODIS convention).
# Window starts: 1, 9, 17, ... The first window of each month:
MONTH_DOY_STARTS <- c(1, 33, 57, 89, 121, 153, 185, 217, 249, 281, 313, 345)
MONTH_LABELS     <- c("J","F","M","A","M","J","J","A","S","O","N","D")

# Per-variable focus-year color (per CT 2026-05-15). Fallback "#D55E00" is
# the SPM biomass orange — kept for any future variable not listed here.
FOCUS_COLORS <- list(
  chlor_a = "seagreen4",
  sst     = "cornflowerblue"
)

# Per-variable position for the upper-corner pixel-count annotations.
# chl plots tend to have a populated right-axis area (fall bloom + winter
# baseline), so annotations sit at the upper-right corner. SST plots have a
# clean upper-left in winter, so annotations sit there.
ANNOTATION_POS <- list(
  chlor_a = list(x = 350, hjust = 1),  # right-aligned at right edge
  sst     = list(x = 1,   hjust = 0)   # left-aligned at left edge
)

PRETTY_NAMES <- list(
  chlor_a = "Chlorophyll-a",
  sst     = "SST"
)

Y_LABELS <- list(
  chlor_a = expression("Chlorophyll-a (mg m"^-3*")"),
  sst     = expression("Sea Surface Temperature (°C)")
)


# ---------------------------------------------------------------------------
# Helper: build overview plot (all years overlaid)
# ---------------------------------------------------------------------------
make_overview_plot <- function(df, variable, polygon_id) {
  # df is already filtered to !sparse & !is.na(value_mean)
  yr_min <- min(df$year)
  yr_max <- max(df$year)
  all_yrs <- sort(unique(df$year))

  legend_breaks <- unique(c(
    all_yrs[seq(1, length(all_yrs), by = 4)],
    max(all_yrs)
  ))

  pretty <- PRETTY_NAMES[[variable]] %||% variable
  title  <- sprintf("%s — 8-day mean %s (%d–%d)",
                    polygon_id, pretty, yr_min, yr_max)

  ggplot(df, aes(x = window_doy_start, y = value_mean,
                 color = factor(year), group = factor(year))) +
    geom_line(linewidth = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(
      aes(ymin = value_mean - value_sd,
          ymax = value_mean + value_sd),
      width = 4, alpha = 0.4
    ) +
    scale_color_viridis_d(
      name   = "Year",
      option = "plasma",
      breaks = legend_breaks
    ) +
    scale_x_continuous(
      breaks = MONTH_DOY_STARTS,
      labels = MONTH_LABELS
    ) +
    scale_y_continuous(labels = comma_format()) +
    guides(color = guide_legend(ncol = min(length(all_yrs), 13))) +
    labs(
      title = title,
      x     = NULL,
      y     = Y_LABELS[[variable]] %||% variable
    ) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom")
}


# ---------------------------------------------------------------------------
# Helper: build per-year climatology plot
# ---------------------------------------------------------------------------
make_year_plot <- function(df_nonsparse, focus_year, variable, polygon_id) {
  # df_nonsparse: all non-sparse rows for this (polygon, variable) combo
  # across all years — used to build climatology + hist range.
  # focus year rows come from filtering df_nonsparse.
  #
  # NOTE: the focus year is intentionally included in the climatology +
  # historical-range computation, matching the biomass reference script
  # (R/01_spm_biomass/DFO_biomass_visualization_CINAR.R). For a record with
  # 30+ years one focus year barely shifts the climatological mean; for a
  # small subset (e.g. only a couple of years cached) the climatology
  # ribbon will visually collapse onto the focus-year line. That is
  # expected behavior, not a bug.

  yr_data <- df_nonsparse %>% filter(year == focus_year)

  # Climatological mean and SD across all non-sparse years, by window
  clim <- df_nonsparse %>%
    group_by(window_doy_start) %>%
    summarise(
      clim_mean = mean(value_mean, na.rm = TRUE),
      clim_sd   = sd(value_mean,   na.rm = TRUE),
      .groups   = "drop"
    ) %>%
    mutate(clim_sd = ifelse(is.na(clim_sd), 0, clim_sd))

  # Historical range: max and min yearly means ± the SD of that year
  hist_range <- df_nonsparse %>%
    group_by(window_doy_start) %>%
    summarise(
      max_mean = max(value_mean, na.rm = TRUE),
      max_sd   = value_sd[which.max(value_mean)],
      min_mean = min(value_mean, na.rm = TRUE),
      min_sd   = value_sd[which.min(value_mean)],
      .groups  = "drop"
    ) %>%
    mutate(
      max_sd   = ifelse(is.na(max_sd), 0, max_sd),
      min_sd   = ifelse(is.na(min_sd), 0, min_sd),
      hist_ymax = max_mean + max_sd,
      hist_ymin = min_mean - min_sd
    )

  pretty       <- PRETTY_NAMES[[variable]]   %||% variable
  focus_color  <- FOCUS_COLORS[[variable]]   %||% "#D55E00"
  ann_pos      <- ANNOTATION_POS[[variable]] %||% list(x = 350, hjust = 1)
  title        <- sprintf("%s — 8-day mean %s — %d",
                          polygon_id, pretty, focus_year)

  # Annotation values from focus year
  max_pix   <- if (nrow(yr_data) > 0) max(yr_data$n_valid_pixels, na.rm = TRUE) else NA
  total_obs <- if (nrow(yr_data) > 0 && any(!is.na(yr_data$n_pixel_obs)))
                 sum(yr_data$n_pixel_obs, na.rm = TRUE) else NA

  ann1 <- if (!is.na(max_pix))
            sprintf("Satellite Pixels in Observed Area: %d", as.integer(max_pix))
          else ""
  ann2 <- if (!is.na(total_obs))
            sprintf("Total Number of Pixels Observed in Year: %d", as.integer(total_obs))
          else ""

  p <- ggplot() +
    # Layer 1: historical range envelope (furthest back)
    geom_ribbon(
      data = hist_range,
      aes(x = window_doy_start, ymin = hist_ymin, ymax = hist_ymax),
      fill = "grey80", alpha = 0.5
    ) +
    # Layer 2: climatological mean ± 1 SD envelope
    geom_ribbon(
      data = clim,
      aes(x = window_doy_start,
          ymin = clim_mean - clim_sd,
          ymax = clim_mean + clim_sd),
      fill = "grey50", alpha = 0.5
    ) +
    # Layer 3: climatological mean line
    geom_line(
      data = clim,
      aes(x = window_doy_start, y = clim_mean),
      linetype = "dashed", color = "grey30", linewidth = 0.8
    ) +
    # Layer 4: focus year — error bars, line, points
    geom_errorbar(
      data = yr_data,
      aes(x    = window_doy_start,
          ymin = value_mean - value_sd,
          ymax = value_mean + value_sd),
      width = 2, color = focus_color, alpha = 0.7
    ) +
    geom_line(
      data = yr_data,
      aes(x = window_doy_start, y = value_mean),
      color = focus_color, linewidth = 1.2
    ) +
    geom_point(
      data = yr_data,
      aes(x = window_doy_start, y = value_mean),
      color = focus_color, size = 2.5
    ) +
    scale_x_continuous(
      breaks = MONTH_DOY_STARTS,
      labels = MONTH_LABELS
    ) +
    scale_y_continuous(labels = comma_format()) +
    labs(
      title = title,
      x     = NULL,
      y     = Y_LABELS[[variable]] %||% variable
    ) +
    annotate("text", x = ann_pos$x, y = Inf, label = ann1,
             hjust = ann_pos$hjust, vjust = 5.5, size = 4, color = "grey20") +
    annotate("text", x = ann_pos$x, y = Inf, label = ann2,
             hjust = ann_pos$hjust, vjust = 7.5, size = 4, color = "grey20") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "none")

  p
}


# ---------------------------------------------------------------------------
# Helper: placeholder PNG for fully-sparse focus year
# ---------------------------------------------------------------------------
make_placeholder_plot <- function() {
  # Used when a focus year has zero non-sparse windows. Data may exist
  # (e.g. OISST at station scale, which always has n_valid_pixels = 1 <
  # n_min = 22) but does not meet the pixel-coverage threshold for plotting.
  ggplot() +
    annotate("text", x = 0.5, y = 0.5,
             label = "Sparse data\n(insufficient pixel coverage per window)",
             hjust = 0.5, vjust = 0.5,
             size = 10, fontface = "bold") +
    theme_void()
}


# ---------------------------------------------------------------------------
# Null-coalescing operator (base R <4.4 compat)
# ---------------------------------------------------------------------------
`%||%` <- function(a, b) if (!is.null(a)) a else b


# ---------------------------------------------------------------------------
# Main function
# ---------------------------------------------------------------------------

#' Generate satellite climatology figures from the summary CSV.
#'
#' @param summary_csv    Path to the satellite summary CSV.
#' @param out_dir        Root output directory for PNGs.
#' @param geography_sets Character vector of geography sets to process; NULL = all.
#' @param polygons       Character vector of polygon_ids to process; NULL = all.
#' @param variables      Character vector of variables to process; NULL = all.
#' @param years          Integer vector of years to process for per-year plots;
#'   NULL = all years present in the CSV.
#'
#' @return Invisibly, a data frame of combos processed (one row per PNG attempt).
plot_satellite_climatology <- function(
    summary_csv    = "summaries/satellite/satellite_summary.csv",
    out_dir        = "plots/satellite",
    geography_sets = NULL,
    polygons       = NULL,
    variables      = NULL,
    years          = NULL
) {
  # ------------------------------------------------------------------
  # Load and filter input data
  # ------------------------------------------------------------------
  df <- readr::read_csv(summary_csv, show_col_types = FALSE)

  if (!is.null(geography_sets)) df <- df %>% filter(geography_set %in% geography_sets)
  if (!is.null(polygons))       df <- df %>% filter(polygon_id    %in% polygons)
  if (!is.null(variables))      df <- df %>% filter(variable      %in% variables)

  if (nrow(df) == 0L) {
    message("[plot] no rows in summary CSV after filtering — nothing to plot")
    return(invisible(data.frame()))
  }

  # ------------------------------------------------------------------
  # Enumerate unique (geography_set, polygon_id, variable) combos
  # ------------------------------------------------------------------
  combos <- df %>%
    distinct(geography_set, polygon_id, variable) %>%
    arrange(geography_set, polygon_id, variable)

  results <- list()

  for (ci in seq_len(nrow(combos))) {
    gset  <- combos$geography_set[ci]
    pid   <- combos$polygon_id[ci]
    vbl   <- combos$variable[ci]

    combo_df <- df %>% filter(geography_set == gset,
                              polygon_id    == pid,
                              variable      == vbl)

    nonsparse <- combo_df %>%
      filter(!sparse, !is.na(value_mean))

    # Per-combo output directory
    png_dir <- file.path(out_dir, gset)
    if (!dir.exists(png_dir)) {
      dir.create(png_dir, recursive = TRUE, showWarnings = FALSE)
    }

    stem <- sprintf("%s_%s_%s", gset, pid, vbl)

    # ----------------------------------------------------------------
    # Overview plot
    # ----------------------------------------------------------------
    yr_min <- if (nrow(nonsparse) > 0) min(nonsparse$year) else min(combo_df$year)
    yr_max <- if (nrow(nonsparse) > 0) max(nonsparse$year) else max(combo_df$year)
    message(sprintf("[plot] %s/%s/%s overview (%d-%d)",
                    gset, pid, vbl, yr_min, yr_max))

    overview_path <- file.path(png_dir, paste0(stem, "_overview.png"))

    if (nrow(nonsparse) == 0L) {
      p_over <- make_placeholder_plot()
    } else {
      p_over <- make_overview_plot(nonsparse, vbl, pid)
    }

    ggsave(overview_path, p_over,
           width = 8, height = 6, dpi = 300, bg = "white")

    results[[length(results) + 1L]] <- data.frame(
      geography_set = gset, polygon_id = pid, variable = vbl,
      type = "overview", year = NA_integer_, path = overview_path
    )

    # ----------------------------------------------------------------
    # Per-year plots
    # ----------------------------------------------------------------
    yr_vec <- sort(unique(combo_df$year))
    if (!is.null(years)) yr_vec <- intersect(yr_vec, years)

    for (fy in yr_vec) {
      message(sprintf("[plot] %s/%s/%s %d", gset, pid, vbl, fy))

      yr_nonsparse <- nonsparse %>% filter(year == fy)
      year_path    <- file.path(png_dir, paste0(stem, "_", fy, ".png"))

      if (nrow(yr_nonsparse) == 0L) {
        p_yr <- make_placeholder_plot()
      } else {
        p_yr <- make_year_plot(nonsparse, fy, vbl, pid)
      }

      ggsave(year_path, p_yr,
             width = 8, height = 6, dpi = 300, bg = "white")

      results[[length(results) + 1L]] <- data.frame(
        geography_set = gset, polygon_id = pid, variable = vbl,
        type = "year", year = fy, path = year_path
      )
    }
  }

  out_df <- dplyr::bind_rows(results)
  message(sprintf("[plot] done — %d PNGs written", nrow(out_df)))
  invisible(out_df)
}
