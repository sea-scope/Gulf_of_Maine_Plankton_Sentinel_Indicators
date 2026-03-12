library(dplyr)
library(ggplot2)
library(viridis)
library(scales)
library(gridExtra)
library(grid)

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir <- getwd()

# Load data
cinar_summary <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_CINAR_summary.csv"))

polygon_names <- c("1" = "Western Scotian Shelf", "3" = "Jordan Basin")

# Filter data
wss_data <- cinar_summary %>% filter(CINAR_poly == 1)
jb_data <- cinar_summary %>% filter(CINAR_poly == 3)

# Get every 4th year for legend breaks
all_years <- sort(unique(cinar_summary$fYear))
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
p_wss_shallow <- make_plot(wss_data, "mean_cfin_0_80", "sd_cfin_0_80", "Western Scotian Shelf (0-80m)")
p_jb_shallow  <- make_plot(jb_data, "mean_cfin_0_80", "sd_cfin_0_80", "Jordan Basin (0-80m)")
p_wss_deep    <- make_plot(wss_data, "mean_cfin_below_80", "sd_cfin_below_80", "Western Scotian Shelf (>80m)")
p_jb_deep     <- make_plot(jb_data, "mean_cfin_below_80", "sd_cfin_below_80", "Jordan Basin (>80m)")

# Shared legend showing every 4th year
get_legend <- function(myggplot) {
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  tmp$grobs[[leg]]
}

legend_plot <- ggplot(wss_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
  geom_line() +
  scale_color_viridis_d(name = NULL, option = "plasma", breaks = legend_breaks) +
  guides(color = guide_legend(ncol = length(legend_breaks))) +
  theme_minimal(base_size = 18) +
  theme(legend.position = "bottom",
        legend.margin = margin(t = -10, b = 0))

shared_legend <- get_legend(legend_plot)

combined_plot <- grid.arrange(
  arrangeGrob(p_wss_shallow, p_jb_shallow,
              p_wss_deep, p_jb_deep,
              ncol = 2, nrow = 2),
  shared_legend,
  heights = c(10, 1)
)
figures_dir <- file.path(work_dir, "figures")
if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)

ggsave(
  filename = file.path(figures_dir, "Biomass_interannual.png"),
  plot = combined_plot,
  width = 10,
  height = 8,
  units = "in",
  dpi = 600,
  bg = "white"
)
