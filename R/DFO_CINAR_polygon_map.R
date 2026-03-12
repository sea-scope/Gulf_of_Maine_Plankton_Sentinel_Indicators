## DFO_CINAR_polygon_map.R
## Step 4e of the DFO Calanus biomass workflow.
## Data-coverage QC map: shows which SPM model grid points fall in which
## CINAR polygon, overlaid on a marmap bathymetric base chart.
## Uses base-R plot.bathy() + points().
##
## Input:  polygons/*_processed_polygons.csv  (uses first file found — arbitrary year/month)
##         poly_*.csv                          (CINAR polygon boundary files in repo root)
##         NOAA ETOPO bathymetry — downloaded via getNOAA.bathy() (internet required)
## Output: figures/CINAR_polygons_map.png
##
## Spatial filter applied before plotting: bathymetry <= 500 m, Y <= 46°N, X <= -60°W.
##
## Map domain: -72 to -60°W, 41 to 46°N.
##   NOTE: This domain clips WSS, Halifax, and Browns Bank, which extend east of -60°W
##   (Halifax reaches ~-57°W). The map is adequate for QC but not a full-coverage figure.
##
## TODO: Add bathymetry caching (like DFO_EcoMon_strata_map.R uses gom_bathy_ecomon.rda)
##   to avoid re-downloading ETOPO on every run.
##
## Required packages: marmap, dplyr, RColorBrewer; internet access required
## Open SPM_calanus_biomass.Rproj before sourcing so getwd() = repo root.

library(marmap)
library(dplyr)
library(RColorBrewer)

rm(list = ls())
# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir    <- getwd()
output_dir  <- file.path(work_dir, "figures")
polygon_dir <- file.path(work_dir, "polygons")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
available_files <- list.files(polygon_dir, pattern = "_polygons\\.csv$", full.names = TRUE)

if (length(available_files) == 0) {
  stop("No polygon files found!")
}

processed_file <- available_files[1]  # Use the first available file
cat("Using file:", basename(processed_file), "\n")

# Load the data
data_polygons <- read.csv(processed_file)
data_polygons <- data_polygons %>%
  filter(bathymetry <= 500) %>%
  filter(Y <= 46) %>%
  filter(X <= -60)
# Filter data to remove missing coordinates
data_clean <- data_polygons %>%
  filter(!is.na(X) & !is.na(Y) & CINAR_poly != 0)

cat("Clean coordinate data:", nrow(data_clean), "points\n")

# Define CINAR polygon names and colors
cinar_names <- c(
  "1" = "Western Scotian Shelf",
  "2" = "Eastern Gulf of Maine",
  "3" = "Jordan Basin",
  "4" = "Browns Bank",
  "5" = "Eastern Scotian Shelf",
  "6" = "Georges Basin and NE Channel",
  "7" = "Grand Manan Basin",
  "8" = "Bay of Fundy"
)

# Warm palette — contrasts with blue ocean background; no blues
cinar_colors <- colorRampPalette(c("#D73027","#F46D43","#FDAE61","#FEE08B",
                                    "#F768A1","#AE017E","#33A02C","#B15928"))(8)
names(cinar_colors) <- c("1", "5", "3", "2", "8", "6", "7", "4")

# Polygon boundary files — same order as cinar_names (IDs 1-8)
poly_files <- c(
  "1" = "poly_WSS_broad.csv",
  "2" = "poly_EGOM_broad.csv",
  "3" = "poly_JB_deep.csv",
  "4" = "poly_Browns_line.csv",
  "5" = "poly_Halifax_line.csv",
  "6" = "poly_GeorgesNEC.csv",
  "7" = "poly_GMB_150.csv",
  "8" = "poly_BOF_latlon.csv"
)

# Get bathymetric data
cat("Downloading bathymetry data...\n")
gom <- getNOAA.bathy(lon1 = -72, lon2 = -60, lat1 = 41, lat2 = 46, resolution = 0.5)

# Create the map
png(filename = file.path(output_dir, "CINAR_polygons_map.png"), width = 12, height = 10, units = "in", res = 300)
par(cex.main = 2.2, font.main = 2, cex.lab = 1.6, font.lab = 2, cex.axis = 1.3,
    xaxs = "i", yaxs = "i")

# Plot bathymetric map — col = "transparent" suppresses the contour lines
plot(gom, image = TRUE, land = TRUE, deep = -500, shallow = 0, step = 50, axes = TRUE,
     bpal = list(c(0, max(gom), "lightgray", "white"),
                 c(-500, 0, "darkblue", "lightblue")),
     xlim = c(-72, -60), ylim = c(41, 46),
     xlab = "Longitude", ylab = "Latitude",
     main = "SPM data grid assignment to CINAR Polygons",
     col = "transparent")

# Plot points colored by CINAR polygon
for (poly_id in sort(unique(data_clean$CINAR_poly))) {
  poly_data <- data_clean[data_clean$CINAR_poly == poly_id, ]
  if (nrow(poly_data) > 0) {
    points(poly_data$X, poly_data$Y,
           col = cinar_colors[as.character(poly_id)],
           pch = 16, cex = 0.8)
  }
}

# Draw polygon borders from poly_*.csv (no header: col 1 = lon, col 2 = lat)
for (poly_id in names(poly_files)) {
  fpath <- file.path(work_dir, "data", poly_files[poly_id])
  if (file.exists(fpath)) {
    bnd <- read.csv(fpath, header = FALSE, col.names = c("lon", "lat"))
    polygon(bnd$lon, bnd$lat,
            border = cinar_colors[poly_id],
            col    = NA,
            lwd    = 2.5)
  }
}

# Legend
cinar_table <- table(data_clean$CINAR_poly)
legend_labels <- paste(cinar_names[names(cinar_table)],
                       paste0("(", cinar_table, ")"))
legend(x = -72, y = 46, legend = legend_labels,
       col = cinar_colors[names(cinar_table)],
       pch = 16, cex = 0.9, pt.cex = 1.4, bg = "white")

dev.off()
graphics.off()
cat("Map saved: CINAR_polygons_map.png\n")
