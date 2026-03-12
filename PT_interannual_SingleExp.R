
rm(list = ls())

# Load required libraries
library(ggplot2)
library(tidyr)
library(dplyr)
library(stringr)
library(ggpubr)

# Set working directory (adjust if needed)

setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_output_record")

# Read data
data <- read.csv("combined_PT_data.csv")
data$EXPERIMENT <- str_replace_all(data$EXPERIMENT, regex("forward", ignore_case = TRUE), "Forward")
data$EXPERIMENT <- str_replace_all(data$EXPERIMENT, regex("15M", ignore_case = TRUE), "15m")


rdata <- read.csv("combined_PT_data.csv")
data <- filter(data, EXPERIMENT %in% c("GMB_15_Back", "GMB_gom4_15_Back"))




unique(data$EXPERIMENT)


# Identify the columns that need to be divided (columns 10 to 17)
cols_to_divide <- 10:17

# Convert to percentage by dividing by Particles and multiplying by 100
data[cols_to_divide] <- sqrt(data[cols_to_divide] / data$Particles * 100)

all_experiments <- unique(data$EXPERIMENT)

# Separate using string patterns
gom4_experiments <- all_experiments[grepl("gom4", all_experiments)]
standard_experiments <- setdiff(all_experiments, gom4_experiments)

# Filter data
gom4_data <- filter(data, EXPERIMENT %in% gom4_experiments)
standard_data <- filter(data, EXPERIMENT %in% standard_experiments)

gom4_data$Year_label<-as.factor(gom4_data$Year)
standard_data$Year_label<-as.factor(standard_data$Year)


# Modify year values in gom4 data
gom4_data <- gom4_data %>%
  mutate(Year_label = paste(Year, "gom4"))  # Append " gom4" to year
# Modify year values in gom4 data

gom4_data <- gom4_data %>%
  mutate(EXPERIMENT = str_replace(EXPERIMENT, "_gom4_", "_"))

# Filter out Year 2016
standard_data <- filter(standard_data, Year != 2016)

# Combine the modified datasets
combined_data <- bind_rows(standard_data, gom4_data)
#combined_data$Year_label<-as.factor(combined_data$Year_label)

# Check if it worked
unique(combined_data$EXPERIMENT)  # Should now only show standard experiment names
unique(combined_data$Year)  # Should show both standard years and "YYYY gom4"


# Group by Experiment, DD, and Year, calculating means
inter <- combined_data %>%
  group_by(EXPERIMENT, DD, Year,Year_label) %>%
  summarise(
    PT_depth = mean(mean.particle.depth, na.rm = TRUE),
    PT_path = mean(mean.path.length, na.rm = TRUE),
    WSS= mean(WSS, na.rm = TRUE),
    EGOM= mean(EGOM, na.rm = TRUE),
    JB= mean(JB, na.rm = TRUE),
    Browns= mean(Browns, na.rm = TRUE),
    Halifax= mean(Halifax, na.rm = TRUE),
    GB_NEC= mean(GB_NEC, na.rm = TRUE),
    GMB_150= mean(GMB_150, na.rm = TRUE),
    BOF= mean(BOF, na.rm = TRUE)
  )

# Filter for DD = 30
select_data <- inter %>%
  filter(DD == 40)

# Drop unnecessary columns (DD, PT_depth, PT_path)
plot_data <- select_data[, -c(2, 5, 6)]

# Order for Metric
metric_order <- c("GMB_150", "BOF", "JB", "WSS", "EGOM", "GB_NEC", "Browns", "Halifax")

# Pivot the data
plot_data_long <- plot_data %>%
  pivot_longer(cols = c(WSS, EGOM, JB, Browns, Halifax, GB_NEC, GMB_150, BOF),
               names_to = "Metric", values_to = "Value") %>%
  mutate(Metric = factor(Metric, levels = metric_order))

# Get unique experiment names
experiments <- unique(plot_data_long$EXPERIMENT)


p <- ggplot(plot_data_long, aes(x = Year, y = Metric, fill = Value)) + 
  geom_tile(color = "white") + 
  scale_fill_distiller(palette = "Greys", direction = 1, limits = c(0, 10), 
                       breaks = c(2, 4, 6, 8, 9,10), labels = c(4, 16, 36, 64, 81, 100)) +
  
  scale_fill_gradient(low = "white", high = "#005f73", limits = c(0, 10),
                      breaks = c(2, 4, 6, 8, 10), labels = c(4, 16, 36, 64, 100)) +
  theme_minimal(base_size = 18) + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
        axis.text.y = element_text(angle = 45, hjust = 1, vjust = -0.5),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        legend.margin = margin(t = 0, r = 0, b = 0, l = -25)) +
  labs(fill = "pct") +
  coord_fixed(ratio = 1.2/1) +
  scale_x_continuous(breaks = seq(1980, 2025, by = 5))
print(p)

setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures")




ggsave(
  filename = "PT_interannual_day40_GMB_15_Back.png",
  plot = p,
  width = 10,
  height = 4,
  units = "in",
  dpi = 600,
  bg = "white"
)











####################


rm(list = ls())

# Load required libraries
library(ggplot2)
library(tidyr)
library(dplyr)
library(stringr)
library(ggpubr)

# Set working directory (adjust if needed)
setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_output_record")

# Read data
data <- read.csv("combined_PT_data.csv")
data$EXPERIMENT <- str_replace_all(data$EXPERIMENT, regex("forward", ignore_case = TRUE), "Forward")
data$EXPERIMENT <- str_replace_all(data$EXPERIMENT, regex("15M", ignore_case = TRUE), "15m")

rdata <- read.csv("combined_PT_data.csv")
data <- filter(data, EXPERIMENT %in% c("GMB_15_Back", "GMB_gom4_15_Back"))

unique(data$EXPERIMENT)

# Identify the columns that need to be divided (columns 10 to 17)
cols_to_divide <- 10:17

# Convert to percentage by dividing by Particles and multiplying by 100
data[cols_to_divide] <- sqrt(data[cols_to_divide] / data$Particles * 100)

all_experiments <- unique(data$EXPERIMENT)

# Separate using string patterns
gom4_experiments <- all_experiments[grepl("gom4", all_experiments)]
standard_experiments <- setdiff(all_experiments, gom4_experiments)

# Filter data
gom4_data <- filter(data, EXPERIMENT %in% gom4_experiments)
standard_data <- filter(data, EXPERIMENT %in% standard_experiments)

gom4_data$Year_label <- as.factor(gom4_data$Year)
standard_data$Year_label <- as.factor(standard_data$Year)

# Modify year values in gom4 data
gom4_data <- gom4_data %>%
  mutate(Year_label = paste(Year, "gom4"))  # Append " gom4" to year

gom4_data <- gom4_data %>%
  mutate(EXPERIMENT = str_replace(EXPERIMENT, "_gom4_", "_"))

# Filter out Year 2016
standard_data <- filter(standard_data, Year != 2016)

# Combine the modified datasets
combined_data <- bind_rows(standard_data, gom4_data)

# Group by Experiment, DD, and Year, calculating means
inter <- combined_data %>%
  group_by(EXPERIMENT, DD, Year, Year_label) %>%
  summarise(
    PT_depth = mean(mean.particle.depth, na.rm = TRUE),
    PT_path = mean(mean.path.length, na.rm = TRUE),
    WSS = mean(WSS, na.rm = TRUE),
    EGOM = mean(EGOM, na.rm = TRUE),
    JB = mean(JB, na.rm = TRUE),
    Browns = mean(Browns, na.rm = TRUE),
    Halifax = mean(Halifax, na.rm = TRUE),
    GB_NEC = mean(GB_NEC, na.rm = TRUE),
    GMB_150 = mean(GMB_150, na.rm = TRUE),
    BOF = mean(BOF, na.rm = TRUE)
  )

# Filter for DD = 40
select_data <- inter %>%
  filter(DD == 40)

# Drop unnecessary columns (DD, PT_depth, PT_path)
plot_data <- select_data[, -c(2, 5, 6)]

# Order for Metric
metric_order <- c("GMB_150", "BOF", "JB", "WSS", "EGOM", "GB_NEC", "Browns", "Halifax")

# Pivot the data
plot_data_long <- plot_data %>%
  pivot_longer(cols = c(WSS, EGOM, JB, Browns, Halifax, GB_NEC, GMB_150, BOF),
               names_to = "Metric", values_to = "Value") %>%
  mutate(Metric = factor(Metric, levels = metric_order))

# Rename y-axis labels
metric_labels <- c(
  "GMB_150" = "Grand Mannan Basin",
  "BOF" = "Bay of Fundy",
  "JB" = "Jordan Basin",
  "WSS" = "Western Scotian Shelf",
  "EGOM" = "Eastern Gulf of Maine",
  "GB_NEC" = "George's Basin & NE Channel",
  "Browns" = "Browns Bank to Halifax",
  "Halifax" = "Eastern Scotian Shelf"
)

p <- ggplot(plot_data_long, aes(x = Year, y = Metric, fill = Value)) + 
  geom_tile(color = "white") + 
  scale_fill_distiller(palette = "Greys", direction = 1, limits = c(0, 10), 
                       breaks = c(2, 4, 6, 8, 9, 10), labels = c(4, 16, 36, 64, 81, 100)) +
  
  scale_fill_gradient(low = "white", high = "#005f73", limits = c(0, 10),
                      breaks = c(2, 4, 6, 8, 10), labels = c(4, 16, 36, 64, 100)) +
  theme_minimal(base_size = 18) + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
        axis.text.y = element_text(angle = 0, hjust = 1, vjust = 0.5),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        legend.margin = margin(t = 0, r = 0, b = 0, l = -25)) +
  labs(fill = "pct") +
  coord_fixed(ratio = 1.5/1) +
  scale_x_continuous(breaks = seq(1980, 2025, by = 5)) +
  scale_y_discrete(labels = metric_labels)

print(p)

setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures")

ggsave(
  filename = "PT_interannual_day40_GMB_15_Back.png",
  plot = p,
  width = 10,
  height = 4,
  units = "in",
  dpi = 600,
  bg = "white"
)

