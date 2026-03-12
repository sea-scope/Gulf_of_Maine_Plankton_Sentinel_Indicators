## DFO_EcoMon_strata_map.R
## Step 4f of the DFO Calanus biomass workflow.
## Map showing which SPM model grid points fall in which EcoMon survey stratum,
## overlaid on a marmap bathymetric base. Stratum boundaries drawn from
## EMstrata_v4_coords.csv; centroids labeled with stratum ID.
## Uses base-R plot.bathy() + points().
##
## Input:  polygons/*_processed_polygons.csv  (uses first file found — arbitrary year/month)
##         EMstrata_v4_coords.csv              (stratum boundary coordinates; repo root)
##         gom_bathy_ecomon.rda                (bathymetry cache; downloaded on first run)
## Output: figures/EcoMon_strata_map.png
##
## Map domain: -76 to -63°W, 38 to 46°N.
## Bathymetry: NOAA ETOPO 1 arc-min, cached as gom_bathy_ecomon.rda after first download.
##   Internet required only on first run.
## Color palette: shuffled warm ramp (YlOrRd + RdPu + YlGn, set.seed(7)) so that
##   spatially adjacent strata receive visually dissimilar colors.
## Legend: top-left, ncol = 3, cex = 1.1; shows stratum ID and grid-point count.
##
## Required packages: marmap, dplyr, RColorBrewer
## Open SPM_calanus_biomass.Rproj before sourcing so getwd() = repo root.

library(marmap)
library(dplyr)
library(RColorBrewer)

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir    <- getwd()
output_dir  <- file.path(work_dir, "figures")
polygon_dir <- file.path(work_dir, "polygons")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

available_files <- list.files(polygon_dir, pattern = "_polygons\\.csv$", full.names = TRUE)
if (length(available_files) == 0) stop("No polygon files found!")

processed_file <- available_files[1]
cat("Using file:", basename(processed_file), "\n")

# Load data and filter to EcoMon-assigned points
data_polygons <- read.csv(processed_file)
data_clean <- data_polygons %>%
  filter(!is.na(X) & !is.na(Y) & EcoMon_poly != 0)

cat("Clean EcoMon data:", nrow(data_clean), "points\n")

strata_ids <- sort(unique(data_clean$EcoMon_poly))
n_strata   <- length(strata_ids)
cat("Strata present:", paste(strata_ids, collapse = ", "), "\n")

# Warm palette shuffled so spatially adjacent strata get dissimilar colors
set.seed(7)
pal_colors <- colorRampPalette(c(brewer.pal(9, "YlOrRd"),
                                  brewer.pal(9, "RdPu"),
                                  brewer.pal(9, "YlGn")))(n_strata)
pal_colors <- sample(pal_colors)
pal <- pal_colors
names(pal) <- as.character(strata_ids)

# Load EcoMon stratum boundary coordinates
strata_coords <- read.csv(file.path(work_dir, "EMstrata_v4_coords.csv"))

# Get bathymetric data — cache as gom_bathy_ecomon.rda after first download
bathy_cache <- file.path(work_dir, "gom_bathy_ecomon.rda")
if (file.exists(bathy_cache)) {
  cat("Loading cached bathymetry...\n")
  load(bathy_cache)   # loads object named 'bathy'
} else {
  cat("Downloading bathymetry data...\n")
  bathy <- getNOAA.bathy(lon1 = -76, lon2 = -63, lat1 = 38, lat2 = 46, resolution = 1)
  save(bathy, file = bathy_cache)
  cat("Bathymetry cached to", bathy_cache, "\n")
}

# Create the map
png(filename = file.path(output_dir, "EcoMon_strata_map.png"),
    width = 14, height = 10, units = "in", res = 300)
par(cex.main = 2.2, font.main = 2, cex.lab = 1.6, font.lab = 2, cex.axis = 1.3)

# col = "transparent" suppresses the bathymetry contour lines
plot(bathy, image = TRUE, land = TRUE, deep = -500, shallow = 0, step = 50, axes = TRUE,
     bpal = list(c(0, max(bathy), "lightgray", "white"),
                 c(-500, 0, "darkblue", "lightblue")),
     xlim = c(-76, -63), ylim = c(38, 46),
     xlab = "Longitude", ylab = "Latitude",
     main = "SPM data grid assignment to EcoMon Strata",
     col = "transparent")

# Plot grid points colored by stratum
for (sid in strata_ids) {
  pts <- data_clean[data_clean$EcoMon_poly == sid, ]
  if (nrow(pts) > 0) {
    points(pts$X, pts$Y,
           col = pal[as.character(sid)],
           pch = 16, cex = 0.6)
  }
}

# Draw stratum boundaries from EMstrata_v4_coords.csv
for (sid in strata_ids) {
  bnd <- strata_coords[strata_coords$stratum_id == sid, ]
  if (nrow(bnd) > 1) {
    # Close the polygon if not already closed
    if (!isTRUE(all.equal(bnd[1, c("lon","lat")], bnd[nrow(bnd), c("lon","lat")]))) {
      bnd <- rbind(bnd, bnd[1, ])
    }
    lines(bnd$lon, bnd$lat, col = "gray20", lwd = 1.0)
  }
}

# Label each stratum at its centroid
for (sid in strata_ids) {
  bnd <- strata_coords[strata_coords$stratum_id == sid, ]
  if (nrow(bnd) > 0) {
    text(mean(bnd$lon), mean(bnd$lat),
         labels = as.character(sid),
         cex = 0.85, col = "black", font = 3)
  }
}

# Legend (2 columns to keep compact)
strata_table  <- table(data_clean$EcoMon_poly)
legend_labels <- paste0(names(strata_table), " (n=", strata_table, ")")
legend("topleft",
       legend = legend_labels,
       col    = pal[names(strata_table)],
       pch    = 16, cex = 1.1, pt.cex = 1.7,
       bg     = "white", ncol = 3,
       title  = "EcoMon Stratum")

dev.off()
graphics.off()
cat("Map saved: EcoMon_strata_map.png\n")
