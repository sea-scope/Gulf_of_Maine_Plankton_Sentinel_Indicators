library(ggplot2)
library(maps)

## Your main bounds
lon_min <- -69; lon_max <- -60
lat_min <- 41;  lat_max <- 46

## World polygons
world <- map_data("world")

## North Atlantic view limits
atl_lon_min <- -90
atl_lon_max <-  10
atl_lat_min <-   25
atl_lat_max <-  70

p<-ggplot() +
  
  ## Land
  geom_polygon(data = world,
               aes(x = long, y = lat, group = group),
               fill = "#D2B48C",   # tan
               color = "black",
               linewidth = 0.2) +
  
  ## Bounding box of Gulf of Maine region
  geom_rect(aes(xmin = lon_min,
                xmax = lon_max,
                ymin = lat_min,
                ymax = lat_max),
            fill = NA,
            color = "red",
            linewidth = 2.5) +
  
  

  
  coord_quickmap(
    xlim = c(atl_lon_min, atl_lon_max),
    ylim = c(atl_lat_min, atl_lat_max),
    expand = FALSE
  ) +
  
  theme_void() +
  theme(
    panel.background = element_rect(fill = "#A6CEE3", color = NA),  # ocean blue
    plot.background  = element_rect(fill = "#A6CEE3", color = NA)
  )


lat_osm <- 55.8617
lon_osm <- -4.2583   # west is negative

## OSM 2026 point (Glasgow)
p<-p+geom_point(aes(x = lon_osm, y = lat_osm),
           shape = 23,          # diamond
           size = 4,
           stroke = 1,
           color = "white",    # outline
           fill = "forestgreen") +

  ## Label (left and above)
  geom_text(aes(x = lon_osm, y = lat_osm,
                label = "OSM 2026, Glasgow"),
            hjust = 1.1,   # shift left
            vjust = -0.5,  # shift up
            size = 6,
            fontface = "bold",
            color = "black")

p

setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_output_figures")

ggsave(
  filename = "inset_map.png",
  plot = p,
  width = 5,
  height = 4,
  units = "in",
  dpi = 600,
  bg = "white"
)


