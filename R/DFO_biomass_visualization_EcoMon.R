## DFO_biomass_visualization_EcoMon.R
## Step 4b of the DFO Calanus biomass workflow.
## Generates seasonal biomass time-series plots for two EcoMon strata of interest:
##   ecomon_36 (Western Gulf of Maine) and ecomon_37 (Wilkinson Basin).
## Produces a 4-panel figure: 2 strata × 2 depth layers (shallow and deep).
##
## Input:  summaries/DFO_biomass_summary.csv  (EcoMon rows only)
## Output: figures/Biomass_interannual_36_37.png
##
## Plot design:
##   x-axis  — month (Jan–Dec tick marks; data typically Apr–Sep)
##   y-axis  — mean biomass (mg/m²) ± 1 SD across grid points in each stratum-month-year
##   color   — year, viridis plasma scale; legend shows every 4th year + final year
##
## Species plotted: Calanus finmarchicus (cfin) only.
##   C. glacialis (cgla) and C. hyperboreus (chyp) columns exist in the summary
##   but are not currently visualized here.
##
## Note: This is a focused two-stratum figure. No script currently produces a
##   comprehensive visualization covering all EcoMon strata in the summary.
##
## Required packages: dplyr, ggplot2, viridis, scales, gridExtra, grid
## Open SPM_calanus_biomass.Rproj before sourcing so getwd() = repo root.

library(dplyr)
library(ggplot2)
library(viridis)
library(scales)
library(gridExtra)
library(grid)

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir <- getwd()

# Load combined summary and filter to EcoMon rows
all_summary    <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_summary.csv"))
ecomon_summary <- all_summary %>% filter(startsWith(polygon, "ecomon"))

# Filter to the two strata of interest
wgom <- ecomon_summary %>% filter(polygon == "ecomon_36")
wb   <- ecomon_summary %>% filter(polygon == "ecomon_37")

# Get every 4th year for legend breaks
all_years <- sort(unique(ecomon_summary$fYear))
legend_breaks <- unique(c(all_years[seq(1, length(all_years), by = 4)], max(all_years)))

# Common plot function
make_plot <- function(df, y_col, se_col, title) {
  ggplot(df, aes(x = month, y = .data[[y_col]], color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = .data[[y_col]] - .data[[se_col]],
                      ymax = .data[[y_col]] + .data[[se_col]]),
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma",
                          breaks = legend_breaks) +
    scale_x_continuous(breaks = 1:12, labels = c("J","F","M","A","M","J","J","A","S","O","N","D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = title, x = "", y = "Biomass (mg/m²)") +
    theme_minimal(base_size = 14) +
    theme(legend.position = "none", plot.title = element_text(size = 14))
}

# 4 plots
p_wss_shallow <- make_plot(wgom, "mean_cfin_0_80", "sd_cfin_0_80", "Stratum 36 (0-80m)")
p_wb_shallow  <- make_plot(wb, "mean_cfin_0_80", "sd_cfin_0_80", "Stratum 37 (0-80m)")
p_wss_deep    <- make_plot(wgom, "mean_cfin_below_80", "sd_cfin_below_80", "Stratum 36 (>80m)")
p_wb_deep     <- make_plot(wb, "mean_cfin_below_80", "sd_cfin_below_80", "Stratum 37 (>80m)")

# Shared legend showing every 4th year
get_legend <- function(myggplot) {
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  tmp$grobs[[leg]]
}

legend_plot <- ggplot(wgom, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
  geom_line() +
  scale_color_viridis_d(name = NULL, option = "plasma", breaks = legend_breaks) +
  guides(color = guide_legend(ncol = length(legend_breaks))) +
  theme_minimal(base_size = 18) +
  theme(legend.position = "bottom",
        legend.margin = margin(t = -10, b = 0))

shared_legend <- get_legend(legend_plot)

combined_plot <- grid.arrange(
  arrangeGrob(p_wss_shallow, p_wb_shallow,
              p_wss_deep, p_wb_deep,
              ncol = 2, nrow = 2),
  shared_legend,
  heights = c(10, 1)
)
figures_dir <- file.path(work_dir, "figures")
if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)

ggsave(
  filename = file.path(figures_dir, "Biomass_interannual_36_37.png"),
  plot = combined_plot,
  width = 10,
  height = 8,
  units = "in",
  dpi = 600,
  bg = "white"
)
