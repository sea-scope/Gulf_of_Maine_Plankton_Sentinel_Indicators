## DFO_biomass_visualization_CINAR.R
## Step 4a of the DFO Calanus biomass workflow.
##
## Two figure types per CINAR polygon:
##
##   1. Overview — one PNG per polygon per depth layer (shallow, deep, total).
##      All years overlaid, viridis plasma colour scale, ± 1 SD error bars.
##      Output: plots/cinar_overview/CINAR_<key>_{shallow,deep,total}.png
##
##   2. Per-year climatology comparison — one PNG per polygon × year × depth.
##      Four layers back-to-front:
##        a) Light envelope: historical range (max mean + SD to min mean - SD)
##        b) Darker envelope: climatological mean ± 1 SD across years
##        c) Dashed line: climatological mean
##        d) Bold line + error bars: focus year (± 1 SD across grid points)
##      Bathymetry annotation (mean ± SD) in top-right corner.
##      Output: plots/cinar_yearly/CINAR_<display_name>_<year>_{shallow,deep,total}.png
##
## Biomass values are converted from mg m⁻² to g m⁻² (÷ 1000) for display.
##
## Input:  summaries/DFO_biomass_summary.csv (CINAR rows)
##
## Required packages: dplyr, ggplot2, viridis, scales

library(dplyr)
library(ggplot2)
library(viridis)
library(scales)

work_dir <- getwd()

# ---------------------------------------------------------------------------
# Load data and convert mg → g
# ---------------------------------------------------------------------------
all_summary   <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_summary.csv"))
cinar_summary <- all_summary %>% filter(!startsWith(polygon, "ecomon"))

# Convert all biomass mean/sd/min/max columns from mg to g
biomass_cols <- grep("^(mean|sd|min|max)_(cfin|cgla|chyp)_", names(cinar_summary), value = TRUE)
cinar_summary <- cinar_summary %>%
  mutate(across(all_of(biomass_cols), ~ .x / 1000))

# Polygon display names (for titles) and file-safe names (for filenames)
polygon_info <- data.frame(
  key          = c("WSS", "EGOM", "JB", "Browns", "Halifax",
                   "GeorgesNEC", "GMB150", "BOF", "SBNMS"),
  display_name = c("Western Scotian Shelf", "Eastern Gulf of Maine",
                   "Jordan Basin", "Browns Bank", "Eastern Scotian Shelf",
                   "Georges Basin and NE Channel", "Grand Manan Basin",
                   "Bay of Fundy", "Stellwagen Bank NMS"),
  file_name    = c("WesternScotianShelf", "EasternGOM",
                   "JordanBasin", "BrownsBank", "EasternScotianShelf",
                   "GeorgesNEC", "GrandManan", "BayOfFundy", "SBNMS"),
  stringsAsFactors = FALSE
)

cat("Available CINAR polygons:",
    paste(sort(unique(cinar_summary$polygon)), collapse = ", "), "\n")

# Output directories
overview_dir <- file.path(work_dir, "plots", "cinar_overview")
yearly_dir   <- file.path(work_dir, "plots", "cinar_yearly")
if (!dir.exists(overview_dir)) dir.create(overview_dir, recursive = TRUE)
if (!dir.exists(yearly_dir))   dir.create(yearly_dir,   recursive = TRUE)

# Common aesthetics
month_labels <- c("J","F","M","A","M","J","J","A","S","O","N","D")
all_years     <- sort(unique(cinar_summary$fYear))
legend_breaks <- unique(c(all_years[seq(1, length(all_years), by = 4)],
                          max(all_years)))

# Depth layer definitions: column stems and labels
depth_layers <- data.frame(
  tag       = c("shallow",       "deep",              "total"),
  mean_col  = c("mean_cfin_0_80","mean_cfin_below_80","mean_cfin_total"),
  sd_col    = c("sd_cfin_0_80",  "sd_cfin_below_80",  "sd_cfin_total"),
  label     = c("(0-80 m)",      "(>80 m)",           "(Total)"),
  stringsAsFactors = FALSE
)

# ===========================================================================
# Helper: overview plot (all years overlaid)
# ===========================================================================
make_overview <- function(df, y_col, sd_col, title) {
  ggplot(df, aes(x = month, y = .data[[y_col]], color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = .data[[y_col]] - .data[[sd_col]],
                      ymax = .data[[y_col]] + .data[[sd_col]]),
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma",
                          breaks = legend_breaks) +
    scale_x_continuous(breaks = 1:12, labels = month_labels) +
    scale_y_continuous(labels = comma_format()) +
    guides(color = guide_legend(ncol = min(length(unique(df$fYear)), 13))) +
    labs(title = title, x = NULL, y = expression("Biomass (g m"^-2*")")) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom")
}

# ===========================================================================
# Helper: per-year climatology comparison plot
# ===========================================================================
make_year_plot <- function(poly_data, focus_year, y_col, sd_col,
                           depth_label, display_name, bathy_text,
                           n_text) {

  # Climatology: mean and SD of the yearly spatial-means, by month
  clim <- poly_data %>%
    group_by(month) %>%
    summarise(clim_mean = mean(.data[[y_col]], na.rm = TRUE),
              clim_sd   = sd(.data[[y_col]],   na.rm = TRUE),
              .groups = "drop") %>%
    mutate(clim_sd = ifelse(is.na(clim_sd), 0, clim_sd))

  # Historical range: max/min year means ± their spatial SDs
  hist_range <- poly_data %>%
    group_by(month) %>%
    summarise(
      max_mean = max(.data[[y_col]], na.rm = TRUE),
      max_sd   = .data[[sd_col]][which.max(.data[[y_col]])],
      min_mean = min(.data[[y_col]], na.rm = TRUE),
      min_sd   = .data[[sd_col]][which.min(.data[[y_col]])],
      .groups = "drop"
    ) %>%
    mutate(
      hist_ymax = max_mean + max_sd,
      hist_ymin = min_mean - min_sd
    )

  # Focus year
  yr_data <- poly_data %>% filter(fYear == focus_year)

  p <- ggplot() +
    # Layer 0 (furthest back): historical range envelope
    geom_ribbon(data = hist_range,
                aes(x = month, ymin = hist_ymin, ymax = hist_ymax),
                fill = "grey80", alpha = 0.5) +
    # Layer 1: climatological mean ± SD envelope
    geom_ribbon(data = clim,
                aes(x = month,
                    ymin = clim_mean - clim_sd,
                    ymax = clim_mean + clim_sd),
                fill = "grey50", alpha = 0.5) +
    # Layer 2: climatological mean
    geom_line(data = clim,
              aes(x = month, y = clim_mean),
              linetype = "dashed", color = "grey30", size = 0.7) +
    # Layer 3: focus year with error bars
    geom_errorbar(data = yr_data,
                  aes(x = month,
                      ymin = .data[[y_col]] - .data[[sd_col]],
                      ymax = .data[[y_col]] + .data[[sd_col]]),
                  width = 0.25, color = "#D55E00", alpha = 0.7) +
    geom_line(data = yr_data,
              aes(x = month, y = .data[[y_col]]),
              color = "#D55E00", size = 1.2) +
    geom_point(data = yr_data,
               aes(x = month, y = .data[[y_col]]),
               color = "#D55E00", size = 2.5) +
    # Scales
    scale_x_continuous(breaks = 1:12, labels = month_labels) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = paste0(display_name, " ", depth_label, " \u2014 ", focus_year),
         x = NULL,
         y = expression("Biomass (g m"^-2*")")) +
    # Bathymetry and sample size annotations
    annotate("text", x = 11, y = Inf, label = bathy_text,
             hjust = 1, vjust = 5.5, size = 5, color = "grey20") +
    annotate("text", x = 11, y = Inf, label = n_text,
             hjust = 1, vjust = 7.5, size = 5, color = "grey20") +
    theme_minimal(base_size = 13) +
    theme(
      legend.position = "none"
    )

  p
}

# ===========================================================================
# Main loop over polygons
# ===========================================================================
for (i in seq_len(nrow(polygon_info))) {
  pkey  <- polygon_info$key[i]
  dname <- polygon_info$display_name[i]
  fname <- polygon_info$file_name[i]

  poly_data <- cinar_summary %>% filter(polygon == pkey)
  if (nrow(poly_data) == 0) {
    cat(sprintf("  %s: no data, skipping\n", pkey))
    next
  }

  cat(sprintf("  %s: %d rows, years %d-%d\n", pkey, nrow(poly_data),
              min(poly_data$fYear), max(poly_data$fYear)))

  # Bathymetry annotation (constant across months/years — take first non-NA)
  bathy_row <- poly_data %>% filter(!is.na(mean_bathy)) %>% slice(1)
  if (nrow(bathy_row) > 0) {
    bathy_text <- sprintf("Depth: %.0f \u00B1 %.0f m",
                          bathy_row$mean_bathy, bathy_row$sd_bathy)
  } else {
    bathy_text <- ""
  }

  years <- sort(unique(poly_data$fYear))

  # n_col mapping: depth tag → sample-size column in summary
  n_col_map <- c(shallow = "n_0_80", deep = "n_below_80", total = "n_0_80")

  for (dl in seq_len(nrow(depth_layers))) {
    tag      <- depth_layers$tag[dl]
    mean_col <- depth_layers$mean_col[dl]
    sd_col   <- depth_layers$sd_col[dl]
    d_label  <- depth_layers$label[dl]
    n_col    <- n_col_map[tag]

    # --- Overview figure ---
    p_over <- make_overview(poly_data, mean_col, sd_col,
                            paste0(dname, " \u2014 ", d_label))
    ggsave(file.path(overview_dir, sprintf("CINAR_%s_%s.png", pkey, tag)),
           p_over, width = 8, height = 6, dpi = 300, bg = "white")

    # --- Per-year climatology figures ---
    for (yr in years) {
      yr_rows <- poly_data %>% filter(fYear == yr)
      n_val   <- max(yr_rows[[n_col]], na.rm = TRUE)
      out_path <- file.path(yearly_dir,
                            sprintf("CINAR_%s_%d_%s.png", fname, yr, tag))

      if (is.na(n_val) || n_val < 22) {
        cat(sprintf("    Low n for %s %d %s (n = %s) — placeholder\n", pkey, yr, tag,
                    ifelse(is.na(n_val), "NA", n_val)))
        p_na <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "Plot Not Available\nDue to Insufficient Datapoints",
                   size = 10, fontface = "bold", hjust = 0.5, vjust = 0.5) +
          theme_void()
        ggsave(out_path, p_na, width = 8, height = 6, dpi = 300, bg = "white")
        next
      }
      n_text <- sprintf("Data Points per Month = %d", n_val)

      p_yr <- make_year_plot(poly_data, yr, mean_col, sd_col,
                             d_label, dname, bathy_text, n_text)
      ggsave(out_path, p_yr, width = 8, height = 6, dpi = 300, bg = "white")
    }
  }
}

cat("\nCINAR visualization complete.\n")
cat("  Overview figures:  plots/cinar_overview/CINAR_<key>_{shallow,deep,total}.png\n")
cat("  Per-year figures:  plots/cinar_yearly/CINAR_<name>_<year>_{shallow,deep,total}.png\n")
