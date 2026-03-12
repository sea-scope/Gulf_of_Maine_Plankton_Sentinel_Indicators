#DFO_biomass_summary_visualization

library(dplyr)
library(ggplot2)
library(viridis)
library(scales)

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir <- getwd()

# Load the CINAR summary data
cinar_summary <- read.csv(file.path(work_dir, "summaries", "DFO_biomass_CINAR_summary.csv"))

# Filter for GMB150 (CINAR_poly = 7)
gmb150_data <- cinar_summary %>%
  filter(CINAR_poly == 7)

cat("GMB150 data loaded:", nrow(gmb150_data), "records\n")
cat("Years available:", paste(sort(unique(gmb150_data$fYear)), collapse = ", "), "\n")
cat("Months available:", paste(sort(unique(gmb150_data$month)), collapse = ", "), "\n")

# Check if we have data
if (nrow(gmb150_data) == 0) {
  stop("No data found for GMB150 (CINAR_poly = 7)")
}

# Create the plot for shallow layer (0-80m)
p1 <- ggplot(gmb150_data, aes(x = month, y = mean_cfin_0_80, color = factor(fYear))) +
  geom_line(size = 1.2, alpha = 0.8) +
  geom_point(size = 2, alpha = 0.9) +
  
  # Add error bars
  geom_errorbar(aes(ymin = mean_cfin_0_80 - sd_cfin_0_80, 
                    ymax = mean_cfin_0_80 + sd_cfin_0_80),
                width = 0.2, alpha = 0.6) +
  
  # Customize colors
  scale_color_viridis_d(name = "Year", option = "plasma") +
  
  # Customize axes
  scale_x_continuous(breaks = 1:12, 
                     labels = c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")) +
  scale_y_continuous(labels = comma_format()) +
  
  # Labels and theme
  labs(
    title = "Calanus finmarchicus Biomass in GMB150 Region (0-80m depth)",
    subtitle = "Seasonal patterns across years (1999-2023)",
    x = "Month",
    y = expression("Biomass (mg/m"^2*")"),
    caption = "Error bars show ± standard deviation"
  ) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA)
  )

# Create the plot for deep layer (>80m)
p2 <- ggplot(gmb150_data, aes(x = month, y = mean_cfin_below_80, color = factor(fYear))) +
  geom_line(size = 1.2, alpha = 0.8) +
  geom_point(size = 2, alpha = 0.9) +
  
  # Add error bars
  geom_errorbar(aes(ymin = mean_cfin_below_80 - sd_cfin_below_80, 
                    ymax = mean_cfin_below_80 + sd_cfin_below_80),
                width = 0.2, alpha = 0.6) +
  
  # Customize colors
  scale_color_viridis_d(name = "Year", option = "plasma") +
  
  # Customize axes
  scale_x_continuous(breaks = 1:12, 
                     labels = c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")) +
  scale_y_continuous(labels = comma_format()) +
  
  # Labels and theme
  labs(
    title = "Calanus finmarchicus Biomass in GMB150 Region (>80m depth)",
    subtitle = "Seasonal patterns across years (1999-2023)",
    x = "Month",
    y = expression("Biomass (mg/m"^2*")"),
    caption = "Error bars show ± standard deviation"
  ) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA)
  )

# Display the plots
print(p1)
print(p2)

# Create a combined plot with both depth layers
library(gridExtra)

p_combined <- grid.arrange(p1, p2, ncol = 1, 
                           top = "Calanus finmarchicus Seasonal Biomass in GMB150 Region")

# Optional: Save the plots
figures_dir <- file.path(work_dir, "figures")
if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
ggsave(file.path(figures_dir, "GMB150_Cfin_shallow_seasonal.png"), p1, width = 12, height = 8, dpi = 300)
ggsave(file.path(figures_dir, "GMB150_Cfin_deep_seasonal.png"), p2, width = 12, height = 8, dpi = 300)
ggsave(file.path(figures_dir, "GMB150_Cfin_combined_seasonal.png"), p_combined, width = 12, height = 14, dpi = 300)

# Print summary statistics
cat("\n=== GMB150 Calanus finmarchicus Summary ===\n")
cat("Shallow layer (0-80m):\n")
cat("  Range:", round(min(gmb150_data$mean_cfin_0_80, na.rm = TRUE), 2), "-", 
    round(max(gmb150_data$mean_cfin_0_80, na.rm = TRUE), 2), "mg/m²\n")
cat("  Mean:", round(mean(gmb150_data$mean_cfin_0_80, na.rm = TRUE), 2), "mg/m²\n")

cat("Deep layer (>80m):\n")
cat("  Range:", round(min(gmb150_data$mean_cfin_below_80, na.rm = TRUE), 2), "-", 
    round(max(gmb150_data$mean_cfin_below_80, na.rm = TRUE), 2), "mg/m²\n")
cat("  Mean:", round(mean(gmb150_data$mean_cfin_below_80, na.rm = TRUE), 2), "mg/m²\n")

# Show peak months by depth layer
shallow_peak <- gmb150_data %>%
  group_by(month) %>%
  summarise(avg_biomass = mean(mean_cfin_0_80, na.rm = TRUE)) %>%
  arrange(desc(avg_biomass)) %>%
  slice(1)

deep_peak <- gmb150_data %>%
  group_by(month) %>%
  summarise(avg_biomass = mean(mean_cfin_below_80, na.rm = TRUE)) %>%
  arrange(desc(avg_biomass)) %>%
  slice(1)

cat("Peak biomass months:\n")
cat("  Shallow layer: Month", shallow_peak$month, "(", round(shallow_peak$avg_biomass, 2), "mg/m²)\n")
cat("  Deep layer: Month", deep_peak$month, "(", round(deep_peak$avg_biomass, 2), "mg/m²)\n")