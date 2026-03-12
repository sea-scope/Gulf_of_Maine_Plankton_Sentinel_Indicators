## plot_particle_tracks.R
## Particle tracking visualization for the Gulf of Maine region.
## Uses ggplot2 + marmap bathymetry + mapdata coastline polygons.
## The land polygon is drawn ON TOP of marine regions, providing clean masking.
##
## Usage:
##   1. Run export_for_R.m in MATLAB from the particle tracking directory
##   2. Set run_date_str below to match the exported files
##   3. Source this script
##
## Required packages: marmap, ggplot2, mapdata

library(marmap)
library(ggplot2)
library(mapdata)

## --- PATHS ---
workdir  <- "C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR"
setwd(workdir)

## --- RUN CONFIG ---
run_date_str <- "20140505"
run_date     <- as.Date(run_date_str, format = "%Y%m%d")

## --- PLOT BOUNDS ---
lon_min <- -69; lon_max <- -60
lat_min <- 41;  lat_max <- 46

## --- TIME STEPS TO PLOT ---
steps     <- c(10, 20, 30, 40, 50, 60)
num_steps <- length(steps)

## --- LOAD PARTICLE DATA ---
Lon <- as.matrix(read.csv(file.path(workdir, paste0("Lon_", run_date_str, ".csv")),
                          header = FALSE))
Lat <- as.matrix(read.csv(file.path(workdir, paste0("Lat_", run_date_str, ".csv")),
                          header = FALSE))

N <- nrow(Lon)
cat(sprintf("Loaded %d particles x %d timesteps\n", N, ncol(Lon)))

## Subsample: every 10th particle
sub_idx <- seq(1, N, by = 10)
Lon_sub <- Lon[sub_idx, , drop = FALSE]
Lat_sub <- Lat[sub_idx, , drop = FALSE]
cat(sprintf("Plotting %d of %d particles\n", length(sub_idx), N))

## Build particle data frame for ggplot
particle_df <- do.call(rbind, lapply(seq_along(steps), function(t) {
  s <- steps[t]
  if (s <= ncol(Lon_sub)) {
    data.frame(
      lon  = Lon_sub[, s],
      lat  = Lat_sub[, s],
      day  = factor(paste0(s, " d post release"), levels = paste0(steps, " d post release"))
    )
  }
}))

## --- LOAD POLYGON BOUNDARIES (pre-clipped in MATLAB) ---
## Polygons were clipped in export_for_R.m so no overlap exists.
## Multiregion polyshapes have NaN-separated boundaries.
load_poly <- function(name) {
  f <- file.path(workdir, paste0("poly_", name, ".csv"))
  if (!file.exists(f)) {
    warning(paste("poly CSV not found:", f))
    return(NULL)
  }
  df <- read.csv(f, header = FALSE)
  colnames(df) <- c("lon", "lat")
  
  ## Handle NaN-separated multiregion polygons from MATLAB polyshape boundary()
  ## Assign a group ID to each region for ggplot
  nan_rows <- which(is.nan(df$lon) | is.nan(df$lat))
  if (length(nan_rows) > 0) {
    df$group <- NA
    g <- 1
    start <- 1
    for (nr in nan_rows) {
      if (nr > start) {
        df$group[start:(nr - 1)] <- g
        g <- g + 1
      }
      start <- nr + 1
    }
    ## Last segment after final NaN
    if (start <= nrow(df)) {
      df$group[start:nrow(df)] <- g
    }
    ## Remove NaN rows
    df <- df[!is.na(df$group), ]
  } else {
    df$group <- 1
  }
  df
}

poly_EGOM    <- load_poly("EGOM_broad")
poly_WSS     <- load_poly("WSS_broad")
poly_BOF     <- load_poly("BOF_latlon")
poly_JB      <- load_poly("JB_deep")
poly_Browns  <- load_poly("Browns_line")
poly_Halifax <- load_poly("Halifax_line")
poly_GMB150  <- load_poly("GMB_150")
poly_GMB200  <- load_poly("GMB_200")
poly_JB250   <- load_poly("JB_250")
poly_GBNEC   <- load_poly("GeorgesNEC")

## --- FETCH BATHYMETRY (cached after first download) ---
bathy_file <- file.path(workdir, "gom_bathy.rda")
if (file.exists(bathy_file)) {
  load(bathy_file)
  cat("Loaded cached bathymetry\n")
} else {
  cat("Downloading NOAA bathymetry (first run only)...\n")
  gom <- getNOAA.bathy(
    lon1 = lon_min - 1, lon2 = lon_max + 1,
    lat1 = lat_min - 1, lat2 = lat_max + 1,
    resolution = 1
  )
  save(gom, file = bathy_file)
  cat("Saved bathymetry cache\n")
}

## Convert bathymetry to data frame for ggplot
bf <- fortify.bathy(gom)

## --- GET COASTLINE POLYGONS ---
## This is the key to clean land masking: real polygon geometry drawn on top
reg <- map_data("world2Hires")
reg <- subset(reg, region %in% c("Canada", "USA"))
reg$long <- (360 - reg$long) * -1  # convert to standard lon

## --- COLOR DEFINITIONS ---
c_EGOM    <- "#99CC80"  # Pale Mint
c_WSS     <- "#667F99"  # Dark Aqua
c_BOF     <- "#6680E6"  # Soft Turquoise
c_JB      <- "#808080"  # Gray
c_Browns  <- "#809980"  # Light Seafoam
c_Halifax <- "#CC9966"  # Deep Teal
c_GMB150  <- "#B3B3B3"  # Light Gray
c_GMB200  <- "#8CA6BF"  # Steel Blue
c_JB250   <- "#B3B3B3"  # Light Gray
c_GBNEC   <- "#5B9E4D"  # Distinct Green

## Particle color palette
particle_pal <- colorRampPalette(c("red", "darkorange", "gold"))(num_steps)
names(particle_pal) <- paste0(steps, " d post release")

## --- BUILD PLOT ---
## Use the fill aesthetic with a named vector so ggplot generates a polygon legend

region_pal <- c(
  "Eastern Gulf of Maine"           = c_EGOM,
  "Western Scotian Shelf"           = c_WSS,
  "Bay of Fundy"                    = c_BOF,
  "Browns Bank to Halifax Line"     = c_Browns,
  "Eastern Scotian Shelf"           = c_Halifax,
  "Grand Manan Basin"               = c_GMB150,
  "Jordan Basin"                    = c_JB,
  "Georges Basin and Northeast Channel" = c_GBNEC
)

p <- ggplot() +
  
  ## Bathymetry contours (background)
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = c(-300), linewidth = 0.4, colour = "grey60") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = c(-200), linewidth = 0.3, colour = "grey70") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = c(-100), linewidth = 0.2, colour = "grey80") +
  
  ## Marine region polygons (pre-clipped in MATLAB, no overlap)
  ## Broad regions
  geom_polygon(data = poly_EGOM,    aes(x = lon, y = lat, group = group, fill = "Eastern Gulf of Maine"),           color = NA,      alpha = 0.5) +
  geom_polygon(data = poly_WSS,     aes(x = lon, y = lat, group = group, fill = "Western Scotian Shelf"),           color = NA,      alpha = 0.5) +
  geom_polygon(data = poly_BOF,     aes(x = lon, y = lat, group = group, fill = "Bay of Fundy"),                    color = NA,      alpha = 0.5) +
  geom_polygon(data = poly_Browns,  aes(x = lon, y = lat, group = group, fill = "Browns Bank to Halifax Line"),     color = NA,      alpha = 0.5) +
  geom_polygon(data = poly_Halifax, aes(x = lon, y = lat, group = group, fill = "Eastern Scotian Shelf"),           color = NA,      alpha = 0.5) +
  ## Smaller / deeper features
  geom_polygon(data = poly_GMB150,  aes(x = lon, y = lat, group = group, fill = "Grand Manan Basin"),               color = "white", alpha = 0.5, linewidth = 0.3) +
  ## GMB 200 m: outline only, no fill, no legend
  geom_polygon(data = poly_GMB200,  aes(x = lon, y = lat, group = group), fill = NA, color = "#5E2D79", linewidth = 0.5, linetype = "dashed", show.legend = FALSE) +
  geom_polygon(data = poly_JB,      aes(x = lon, y = lat, group = group, fill = "Jordan Basin"),                    color = "white", alpha = 0.5, linewidth = 0.3) +
  ## geom_polygon(data = poly_JB250,   aes(x = lon, y = lat, group = group), fill = c_JB250,  color = "white", alpha = 0.5, linewidth = 0.3) +
  geom_polygon(data = poly_GBNEC,   aes(x = lon, y = lat, group = group, fill = "Georges Basin and Northeast Channel"), color = "white", alpha = 0.5, linewidth = 0.3) +
  
  scale_fill_manual(values = region_pal, name = NULL) +
  
  ## Land polygons ON TOP to mask any bleed
  geom_polygon(data = reg, aes(x = long, y = lat, group = group),
               fill = "#8B7D6B", color = "grey30", linewidth = 0.4) +
  
  ## Particles
  geom_point(data = particle_df, aes(x = lon, y = lat, color = day),
             size = 0.8, alpha = 0.5) +
  scale_color_manual(values = particle_pal, name = "Backwards Track Duration") +
  
  ## Station/buoy markers (uncomment to enable)
  # geom_point(aes(x = -66.85, y = 44.93), shape = 18, size = 3, color = "green3") +
  # geom_point(aes(x = -67.87, y = 43.50), shape = 24, size = 2, color = "black", fill = "cyan") +
  # geom_point(aes(x = -65.90, y = 42.34), shape = 25, size = 2, color = "black", fill = "blue") +
  
  ## Projection and limits
  coord_map(xlim = c(lon_min, lon_max), ylim = c(lat_min, lat_max)) +
  
  ## Labels and theme
  # labs(
  #   title = paste("Particles Released", format(run_date, "%d %b, %Y")),
  #   x = "Longitude", y = "Latitude"
  #   
  ## Labels and theme
  labs(
    title = NULL,
    x = NULL,
    y = NULL
  ) +
  theme_bw(base_size = 20) +
  theme(
    legend.position = c(0.98, 0.02),
    legend.justification = c(1, 0),
    legend.background = element_rect(fill = alpha("white", 0.8), color = NA),
    legend.key.size = unit(0.5, "cm"),
    legend.spacing.y = unit(0.1, "cm"),
    legend.box = "vertical",
    panel.grid = element_line(color = "grey90", linewidth = 0.2)
  ) +
  guides(
    fill  = guide_legend(order = 1, override.aes = list(alpha = 0.6)),
    color = guide_legend(order = 2, override.aes = list(size = 2, alpha = 0.8))
  )


## --- SAVE ---

setwd("C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_output_figures")


outfile <- paste0("GMB15_", run_date_str, ".png")

ggsave(
  filename = outfile,
  plot = p,
  width = 12,
  height = 8,
  units = "in",
  dpi = 600,
  bg = "white"
)




outfile <- paste0("PT_", run_date_str, ".png")
ggsave(outfile, plot = p, width = 14, height = 9.5, dpi = 600)
cat(sprintf("Saved: %s\n", outfile))






