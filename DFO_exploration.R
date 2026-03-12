

Bioenergy_1999_04_3D_test <- readRDS("C:/Users/camer/Desktop/SPM_calanus_biomass/Bioenergy_3D/Bioenergy_1999_04_3D.rds")
head(Bioenergy_1999_04_3D_test)

Bioenergy_1999_04_3D <- readRDS("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass/Bioenergy_1999_04_3D.rds")


setdiff(names(Bioenergy_1999_04_3D_test), names(Bioenergy_1999_04_3D))   # headers in df1 not in df2
setdiff(names(Bioenergy_1999_04_3D), names(Bioenergy_1999_04_3D_test))   # headers in df2 not in df1

intersect(names(Bioenergy_1999_04_3D_test), names(Bioenergy_1999_04_3D)) # shared headers


unique(Bioenergy_1999_04_3D$Region)
unique(Bioenergy_1999_04_3D$REGION)


range(Bioenergy_1999_04_3D$X)
range(Bioenergy_1999_04_3D$Y)


range(Bioenergy_1999_04_3D_test$X)
range(Bioenergy_1999_04_3D_test$Y)

Bioenergy_1999_04 <- readRDS("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR/Bioenergy_1999_04.rds")


library(dplyr)
library(tidyr)
library(ggplot2)


# Load source data
Bioenergy_1999_04_3D <- readRDS("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR/Bioenergy_1999_04_3D.rds")

# Shallow layer: Zlayer ≤ 80
Bioenergy_1999_04_100 <- Bioenergy_1999_04_3D %>%
  filter(Zlayer <= 80) %>%
  group_by(Label, X, Y, Region, bathymetry, fYear, month, REGION) %>%
  summarise(
    cfin_C4.6dw.mgm2 = first(cfin_C4.6dw.mgm2),
    cgla_C4.6dw.mgm2 = first(cgla_C4.6dw.mgm2),
    chyp_C4.6dw.mgm2 = first(chyp_C4.6dw.mgm2),
    sum_cfin_100 = sum(DW_Zlayer_mg_cfin, na.rm = TRUE),
    sum_cgla_100 = sum(DW_Zlayer_mg_cgla, na.rm = TRUE),
    sum_chyp_100 = sum(DW_Zlayer_mg_chyp, na.rm = TRUE),
    .groups = 'drop'
  )

# Deep (diapause) layer: Zlayer > 100
Bioenergy_1999_04_Diapause <- Bioenergy_1999_04_3D %>%
  filter(Zlayer > 80) %>%
  group_by(Label, X, Y, Region, bathymetry, fYear, month, REGION) %>%
  summarise(
    sum_cfin_Diapause = sum(DW_Zlayer_mg_cfin, na.rm = TRUE),
    sum_cgla_Diapause = sum(DW_Zlayer_mg_cgla, na.rm = TRUE),
    sum_chyp_Diapause = sum(DW_Zlayer_mg_chyp, na.rm = TRUE),
    .groups = 'drop'
  )

# Merge side-by-side
Bioenergy_1999_04_merged <- full_join(
  Bioenergy_1999_04_100,
  Bioenergy_1999_04_Diapause,
  by = c("Label", "X", "Y", "Region", "bathymetry", "fYear", "month", "REGION")
)

########




bar_data <- Bioenergy_1999_04_merged %>%
  group_by(REGION) %>%
  summarise(
    mean_100 = mean(sum_cfin_100 / bathymetry, na.rm = TRUE),
    mean_diapause = mean(sum_cfin_Diapause / bathymetry, na.rm = TRUE),
    sd_100 = sd(sum_cfin_100 / bathymetry, na.rm = TRUE),
    sd_diapause = sd(sum_cfin_Diapause / bathymetry, na.rm = TRUE)
  ) %>%
  pivot_longer(cols = c(mean_100, mean_diapause), names_to = "Layer", values_to = "mean") %>%
  mutate(
    Layer = recode(Layer, mean_100 = "0–100 m", mean_diapause = ">100 m"),
    sd = ifelse(Layer == "0–100 m", sd_100, sd_diapause)
  )

ggplot(bar_data, aes(x = REGION, y = mean, fill = Layer)) +
  geom_bar(stat = "identity", position = position_dodge(0.9)) +
  geom_errorbar(aes(ymin = mean, ymax = mean + sd),
                position = position_dodge(0.9), width = 0.25) +
  scale_fill_manual(values = c("0–100 m" = "steelblue", ">100 m" = "firebrick")) +
  labs(x = "Region", y = "C. finmarchicus biomass (mg/m³)",
       fill = "Depth Layer",
       title = "Mean C. finmarchicus biomass by region and depth layer") +
  theme_minimal()

#Fundy, GB, GOM, SS

library(ggplot2)
library(viridis)
library(tidyr)

map_data <- Bioenergy_1999_04_merged %>%
  select(X, Y, sum_cfin_100, sum_cfin_Diapause) %>%
  pivot_longer(cols = c(sum_cfin_100, sum_cfin_Diapause),
               names_to = "Layer", values_to = "biomass_m3") %>%
  mutate(Layer = recode(Layer,
                        sum_cfin_100 = "0–100 m",
                        sum_cfin_Diapause = ">100 m"))

ggplot(map_data, aes(x = X, y = Y, color = biomass_m3)) +
  geom_point(size = 0.5, alpha = 0.7) +
  scale_color_viridis(name = "Biomass", limits = c(1, 10000)) +
  facet_wrap(~Layer) +
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude",
       title = "C. finmarchicus biomass distribution by depth layer") +
  theme_minimal()





ggplot(map_data, aes(x = X, y = Y, color = biomass_m3)) +
  geom_point(size = 0.5, alpha = 0.7) +
  scale_color_viridis(
    name = "Biomass\n(mg/m²)",
    trans = "log10",
    limits = c(1, 100)  # set to appropriate range for your data
  ) +
  facet_wrap(~Layer) +
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude",
       title = "C. finmarchicus biomass distribution by depth layer") +
  theme_minimal()












map_data <- Bioenergy_1999_04_merged %>%
  filter(REGION %in% c("Fundy", "GB", "GOM", "SS"),
         bathymetry < 500) %>%
  select(X, Y, sum_cfin_100, sum_cfin_Diapause) %>%
  pivot_longer(cols = c(sum_cfin_100, sum_cfin_Diapause),
               names_to = "Layer", values_to = "biomass_m3") %>%
  mutate(Layer = recode(Layer,
                        sum_cfin_100 = "0–100 m",
                        sum_cfin_Diapause = ">100 m"))



ggplot(map_data, aes(x = X, y = Y, color = biomass_m3)) +
  geom_point(size = 0.5, alpha = 0.7) +
  scale_color_viridis(
    name = "Biomass\n(mg/m²)",
    trans = "log10"
  ) +
  facet_wrap(~Layer) +
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude",
       title = "C. finmarchicus biomass (Fundy, GB, GOM, SS; depth <500 m)") +
  theme_minimal()






library(akima)

interp_grid <- with(map_data,
                    akima::interp(x = X, y = Y, z = log10(biomass_m3),
                                  duplicate = "mean", nx = 200, ny = 200))

interp_df <- expand.grid(X = interp_grid$x, Y = interp_grid$y) %>%
  mutate(biomass_log10 = as.vector(interp_grid$z))

ggplot(interp_df, aes(x = X, y = Y, fill = biomass_log10)) +
  geom_raster(interpolate = TRUE) +
  scale_fill_viridis(name = "log10 Biomass") +
  facet_wrap(~ map_data$Layer[1]) +  # handle faceting manually if you want both layers
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude",
       title = "Smoothed C. finmarchicus biomass") +
  theme_minimal()




