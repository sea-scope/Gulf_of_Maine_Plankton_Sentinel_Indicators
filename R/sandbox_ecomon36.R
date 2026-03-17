## sandbox_ecomon36.R
## Interactive sandbox for tuning plot aesthetics on EcoMon stratum 36
## before running the full visualization pipeline.
##
## Usage: Open in RStudio, run line-by-line or block-by-block.
##        Tweak any ggplot element, re-run, and inspect in the Plots pane.
##        When satisfied, port changes back to DFO_biomass_visualization_EcoMon.R
##        (and DFO_biomass_visualization_CINAR.R — same helpers).
##
## Does NOT save any files unless you uncomment the ggsave calls at the bottom.

library(dplyr)
library(ggplot2)
library(viridis)
library(scales)

work_dir <- getwd()

# ---------------------------------------------------------------------------
# Load stratum 36 data
# ---------------------------------------------------------------------------
all_summary <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_summary.csv"))

# Convert mg → g for all biomass columns
biomass_cols <- grep("^(mean|sd|min|max)_(cfin|cgla|chyp)_", names(all_summary), value = TRUE)
all_summary <- all_summary %>%
  mutate(across(all_of(biomass_cols), ~ .x / 1000))

s36 <- all_summary %>%
  filter(polygon == "ecomon_36")

cat(sprintf("Stratum 36: %d rows, years %d-%d\n",
            nrow(s36), min(s36$fYear), max(s36$fYear)))

# Depth layer columns — pick one to work with (change as needed)
y_col  <- "mean_cfin_0_80"      # shallow
sd_col <- "sd_cfin_0_80"
depth_label <- "(0-80 m)"
# y_col  <- "mean_cfin_below_80"  # deep
# sd_col <- "sd_cfin_below_80"
# depth_label <- ">80 m"
# y_col  <- "mean_cfin_total"     # total
# sd_col <- "sd_cfin_total"
# depth_label <- "Total"

month_labels <- c("J","F","M","A","M","J","J","A","S","O","N","D")
all_years     <- sort(unique(s36$fYear))
legend_breaks <- unique(c(all_years[seq(1, length(all_years), by = 4)],
                          max(all_years)))

# Bathymetry text
bathy_row <- s36 %>% filter(!is.na(mean_bathy)) %>% slice(1)
bathy_text <- if (nrow(bathy_row) > 0) {
  sprintf("Depth: %.0f \u00B1 %.0f m", bathy_row$mean_bathy, bathy_row$sd_bathy)
} else ""

# ===========================================================================
# OVERVIEW PLOT — all years overlaid
# ===========================================================================
p_overview <- ggplot(s36, aes(x = month, y = .data[[y_col]], color = factor(fYear))) +
  geom_line(size = 0.8, alpha = 0.8) +
  geom_point(size = 1.5, alpha = 0.9) +
  geom_errorbar(aes(ymin = .data[[y_col]] - .data[[sd_col]],
                    ymax = .data[[y_col]] + .data[[sd_col]]),
                width = 0.2, alpha = 0.6) +
  scale_color_viridis_d(name = "Year", option = "plasma",
                        breaks = legend_breaks) +
  scale_x_continuous(breaks = 1:12, labels = month_labels) +
  scale_y_continuous(labels = comma_format()) +
  guides(color = guide_legend(ncol = min(length(all_years), 13))) +
  labs(title = paste("EcoMon Stratum 36 —", depth_label),
       x = NULL, y = expression("Biomass (g m"^-2*")")) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

print(p_overview)

# ===========================================================================
# PER-YEAR PLOT — pick a focus year to preview
# ===========================================================================
focus_year <- 2010   # <-- change this to any year in your dataset

# Climatology: mean of means ± SD
clim <- s36 %>%
  group_by(month) %>%
  summarise(clim_mean = mean(.data[[y_col]], na.rm = TRUE),
            clim_sd   = sd(.data[[y_col]],   na.rm = TRUE),
            .groups = "drop") %>%
  mutate(clim_sd = ifelse(is.na(clim_sd), 0, clim_sd))

# Historical range: for each month, find the year with max/min mean biomass,
# then extend by that year's spatial SD
hist_range <- s36 %>%
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

yr_data <- s36 %>% filter(fYear == focus_year)

# Sample size for the focus year and depth layer
n_col <- "n_0_80"  # change to "n_below_80" for deep
n_val <- max(yr_data[[n_col]], na.rm = TRUE)
n_text <- sprintf("Data Points per Month = %d", n_val)
cat(sprintf("Focus year %d: %s (placeholder if < 10)\n", focus_year, n_text))

p_year <- ggplot() +
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
  # Layer 3: focus year
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
  labs(title = paste0("EcoMon Stratum 36 ", depth_label, " \u2014 ", focus_year),
       x = NULL,
       y = expression("Biomass (g m"^-2*")")) +
  # Bathymetry and sample size annotations
  annotate("text", x = 11, y = Inf, label = bathy_text,
           hjust = 1, vjust = 5.5, size = 5, color = "grey20") +
  annotate("text", x = 11, y = Inf, label = n_text,
           hjust = 1, vjust = 7.5, size = 5, color = "grey20") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")

print(p_year)

# ===========================================================================
# PLACEHOLDER PLOT — shown when n < 10
# ===========================================================================
p_placeholder <- ggplot() +
  annotate("text", x = 0.5, y = 0.5,
           label = "Plot Not Available\nDue to Insufficient Datapoints",
           size = 10, fontface = "bold", hjust = 0.5, vjust = 0.5) +
  theme_void()

print(p_placeholder)

# ===========================================================================
# Uncomment to save when you're happy with the look:
# ===========================================================================
# ggsave("plots/ecomon_overview/EcoMon_stratum_36_shallow.png",
#        p_overview, width = 8, height = 6, dpi = 300, bg = "white")
# ggsave(sprintf("plots/ecomon_yearly/EcoMon_36_%d_shallow.png", focus_year),
#        p_year, width = 8, height = 6, dpi = 300, bg = "white")
