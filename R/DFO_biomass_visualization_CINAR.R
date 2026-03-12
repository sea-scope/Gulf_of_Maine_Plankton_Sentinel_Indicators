## DFO_biomass_visualization_CINAR.R
## Step 4a of the DFO Calanus biomass workflow.
## Generates seasonal biomass time-series plots for all 8 CINAR analysis regions.
## Produces two 8-panel composite figures: shallow layer (0-80 m) and deep layer (>80 m).
##
## Input:  summaries/DFO_biomass_summary.csv  (CINAR rows only; polygon column = short key)
## Output: figures/CINAR_biomass_shallow.png
##         figures/CINAR_biomass_deep.png
##
## Plot design:
##   x-axis  — month (Jan–Dec tick marks; data typically Apr–Sep)
##   y-axis  — mean biomass (mg/m²) ± 1 SD across grid points in each polygon-month-year
##   color   — year, viridis plasma scale; legend shows every 4th year + final year
##
## Species plotted: Calanus finmarchicus (cfin) only.
##   C. glacialis (cgla) and C. hyperboreus (chyp) columns exist in the summary
##   but are not currently visualized here.
##
## CINAR polygon keys used in the 'polygon' column of the summary:
##   "WSS"  "EGOM"  "JB"  "Browns"  "Halifax"  "GeorgesNEC"  "GMB150"  "BOF"
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

# Load combined summary and filter to CINAR rows (polygon names, not "ecomon_*")
all_summary   <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_summary.csv"))
cinar_summary <- all_summary %>% filter(!startsWith(polygon, "ecomon"))

# Full region names for plot titles
polygon_names <- c(
  "WSS"       = "Western Scotian Shelf",
  "EGOM"      = "Eastern Gulf of Maine",
  "JB"        = "Jordan Basin",
  "Browns"    = "Browns Bank",
  "Halifax"   = "Eastern Scotian Shelf",
  "GeorgesNEC"= "Georges Basin and NE Channel",
  "GMB150"    = "Grand Manan Basin",
  "BOF"       = "Bay of Fundy"
)

cat("Available CINAR polygons:", paste(sort(unique(cinar_summary$polygon)), collapse = ", "), "\n")

# Function to extract legend
get_legend <- function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

# Create plots for each CINAR polygon - SHALLOW LAYER (0-80m)
cat("\n=== Creating Shallow Layer Plots ===\n")

# WSS (1) - Shallow
wss_data <- cinar_summary %>% filter(polygon == "WSS")
if (nrow(wss_data) > 0) {
  p1_shallow <- ggplot(wss_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["WSS"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p1_shallow <- ggplot() + labs(title = "WSS - No Data") + theme_void()
}

# EGOM (2) - Shallow
egom_data <- cinar_summary %>% filter(polygon == "EGOM")
if (nrow(egom_data) > 0) {
  p2_shallow <- ggplot(egom_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["EGOM"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p2_shallow <- ggplot() + labs(title = "EGOM - No Data") + theme_void()
}

# JB (3) - Shallow
jb_data <- cinar_summary %>% filter(polygon == "JB")
if (nrow(jb_data) > 0) {
  p3_shallow <- ggplot(jb_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["JB"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p3_shallow <- ggplot() + labs(title = "JB - No Data") + theme_void()
}

# Browns (4) - Shallow
browns_data <- cinar_summary %>% filter(polygon == "Browns")
if (nrow(browns_data) > 0) {
  p4_shallow <- ggplot(browns_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["Browns"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p4_shallow <- ggplot() + labs(title = "Browns - No Data") + theme_void()
}

# Halifax (5) - Shallow
halifax_data <- cinar_summary %>% filter(polygon == "Halifax")
if (nrow(halifax_data) > 0) {
  p5_shallow <- ggplot(halifax_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["Halifax"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p5_shallow <- ggplot() + labs(title = "Halifax - No Data") + theme_void()
}

# GeorgesNEC (6) - Shallow
georgesnec_data <- cinar_summary %>% filter(polygon == "GeorgesNEC")
if (nrow(georgesnec_data) > 0) {
  p6_shallow <- ggplot(georgesnec_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["GeorgesNEC"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p6_shallow <- ggplot() + labs(title = "GeorgesNEC - No Data") + theme_void()
}

# GMB150 (7) - Shallow
gmb150_data <- cinar_summary %>% filter(polygon == "GMB150")
if (nrow(gmb150_data) > 0) {
  p7_shallow <- ggplot(gmb150_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["GMB150"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p7_shallow <- ggplot() + labs(title = "GMB150 - No Data") + theme_void()
}

# BOF (8) - Shallow
bof_data <- cinar_summary %>% filter(polygon == "BOF")
if (nrow(bof_data) > 0) {
  p8_shallow <- ggplot(bof_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, ymax = mean_cfin_0_80 + sd_cfin_0_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["BOF"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p8_shallow <- ggplot() + labs(title = "BOF - No Data") + theme_void()
}

# Create shared legend for shallow layer with 12 columns
if (nrow(wss_data) > 0 || nrow(egom_data) > 0 || nrow(jb_data) > 0 || nrow(browns_data) > 0 || 
    nrow(halifax_data) > 0 || nrow(georgesnec_data) > 0 || nrow(gmb150_data) > 0 || nrow(bof_data) > 0) {
  
  # Use the first available dataset to create legend
  legend_data <- NULL
  if (nrow(wss_data) > 0) legend_data <- wss_data
  else if (nrow(egom_data) > 0) legend_data <- egom_data
  else if (nrow(jb_data) > 0) legend_data <- jb_data
  else if (nrow(browns_data) > 0) legend_data <- browns_data
  else if (nrow(halifax_data) > 0) legend_data <- halifax_data
  else if (nrow(georgesnec_data) > 0) legend_data <- georgesnec_data
  else if (nrow(gmb150_data) > 0) legend_data <- gmb150_data
  else if (nrow(bof_data) > 0) legend_data <- bof_data
  
  legend_plot_shallow <- ggplot(legend_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    guides(color = guide_legend(ncol = 13)) +
    theme_minimal() +
    theme(legend.position = "top")
  
  shared_legend_shallow <- get_legend(legend_plot_shallow)
  
  # Combine plots with shared legend
  shallow_combined <- grid.arrange(
    shared_legend_shallow,
    arrangeGrob(p1_shallow, p2_shallow, p3_shallow, p4_shallow,
                p5_shallow, p6_shallow, p7_shallow, p8_shallow,
                ncol = 4, nrow = 2),
    heights = c(2, 10),
    top = "Calanus finmarchicus Seasonal Biomass - Shallow Layer (0-80m) All CINAR Regions"
  )
} else {
  shallow_combined <- grid.arrange(
    p1_shallow, p2_shallow, p3_shallow, p4_shallow,
    p5_shallow, p6_shallow, p7_shallow, p8_shallow,
    ncol = 4, nrow = 2,
    top = "Calanus finmarchicus Seasonal Biomass - Shallow Layer (0-80m) All CINAR Regions"
  )
}

# Create plots for DEEP LAYER (>80m)
cat("\n=== Creating Deep Layer Plots ===\n")

# WSS (1) - Deep
if (nrow(wss_data) > 0) {
  p1_deep <- ggplot(wss_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["WSS"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p1_deep <- ggplot() + labs(title = "WSS - No Data") + theme_void()
}

# EGOM (2) - Deep
if (nrow(egom_data) > 0) {
  p2_deep <- ggplot(egom_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["EGOM"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p2_deep <- ggplot() + labs(title = "EGOM - No Data") + theme_void()
}

# JB (3) - Deep
if (nrow(jb_data) > 0) {
  p3_deep <- ggplot(jb_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["JB"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p3_deep <- ggplot() + labs(title = "JB - No Data") + theme_void()
}

# Browns (4) - Deep
if (nrow(browns_data) > 0) {
  p4_deep <- ggplot(browns_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["Browns"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p4_deep <- ggplot() + labs(title = "Browns - No Data") + theme_void()
}

# Halifax (5) - Deep
if (nrow(halifax_data) > 0) {
  p5_deep <- ggplot(halifax_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["Halifax"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p5_deep <- ggplot() + labs(title = "Halifax - No Data") + theme_void()
}

# GeorgesNEC (6) - Deep
if (nrow(georgesnec_data) > 0) {
  p6_deep <- ggplot(georgesnec_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["GeorgesNEC"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p6_deep <- ggplot() + labs(title = "GeorgesNEC - No Data") + theme_void()
}

# GMB150 (7) - Deep
if (nrow(gmb150_data) > 0) {
  p7_deep <- ggplot(gmb150_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["GMB150"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p7_deep <- ggplot() + labs(title = "GMB150 - No Data") + theme_void()
}

# BOF (8) - Deep
if (nrow(bof_data) > 0) {
  p8_deep <- ggplot(bof_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    geom_point(size = 1.5, alpha = 0.9) +
    geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, ymax = mean_cfin_below_80 + sd_cfin_below_80), 
                  width = 0.2, alpha = 0.6) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    scale_x_continuous(breaks = 1:12, labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")) +
    scale_y_continuous(labels = comma_format()) +
    labs(title = polygon_names["BOF"], x = "Month", y = "Biomass (mg/m²)") +
    theme_minimal() +
    theme(legend.position = "none", plot.title = element_text(size = 11))
} else {
  p8_deep <- ggplot() + labs(title = "BOF - No Data") + theme_void()
}

# Create shared legend for deep layer with 12 columns
if (nrow(wss_data) > 0 || nrow(egom_data) > 0 || nrow(jb_data) > 0 || nrow(browns_data) > 0 || 
    nrow(halifax_data) > 0 || nrow(georgesnec_data) > 0 || nrow(gmb150_data) > 0 || nrow(bof_data) > 0) {
  
  # Use the same legend data as shallow layer
  legend_data <- NULL
  if (nrow(wss_data) > 0) legend_data <- wss_data
  else if (nrow(egom_data) > 0) legend_data <- egom_data
  else if (nrow(jb_data) > 0) legend_data <- jb_data
  else if (nrow(browns_data) > 0) legend_data <- browns_data
  else if (nrow(halifax_data) > 0) legend_data <- halifax_data
  else if (nrow(georgesnec_data) > 0) legend_data <- georgesnec_data
  else if (nrow(gmb150_data) > 0) legend_data <- gmb150_data
  else if (nrow(bof_data) > 0) legend_data <- bof_data
  
  legend_plot_deep <- ggplot(legend_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
    geom_line(size = 0.8, alpha = 0.8) +
    scale_color_viridis_d(name = "Year", option = "plasma") +
    guides(color = guide_legend(ncol = 13)) +
    theme_minimal() +
    theme(legend.position = "top")
  
  shared_legend_deep <- get_legend(legend_plot_deep)
  
  # Combine plots with shared legend
  deep_combined <- grid.arrange(
    shared_legend_deep,
    arrangeGrob(p1_deep, p2_deep, p3_deep, p4_deep,
                p5_deep, p6_deep, p7_deep, p8_deep,
                ncol = 4, nrow = 2),
    heights = c(2, 10),
    top = "Calanus finmarchicus Seasonal Biomass - Deep Layer (>80m) All CINAR Regions"
  )
} else {
  deep_combined <- grid.arrange(
    p1_deep, p2_deep, p3_deep, p4_deep,
    p5_deep, p6_deep, p7_deep, p8_deep,
    ncol = 4, nrow = 2,
    top = "Calanus finmarchicus Seasonal Biomass - Deep Layer (>80m) All CINAR Regions"
  )
}

# Save the combined plots
output_dir <- file.path(work_dir, "figures")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
ggsave(file.path(output_dir, "CINAR_all_regions_shallow.png"), shallow_combined, width = 20, height = 12, dpi = 300)
ggsave(file.path(output_dir, "CINAR_all_regions_deep.png"), deep_combined, width = 20, height = 12, dpi = 300)

cat("Plots saved to:", output_dir, "\n")

# Print summary of data availability
cat("\n=== Data Availability Summary ===\n")
summary_table <- cinar_summary %>%
  group_by(polygon) %>%
  summarise(
    region_name      = polygon_names[polygon[1]],
    n_records        = n(),
    years_span       = paste(min(fYear), "-", max(fYear)),
    months_available = length(unique(month)),
    .groups = 'drop'
  )
