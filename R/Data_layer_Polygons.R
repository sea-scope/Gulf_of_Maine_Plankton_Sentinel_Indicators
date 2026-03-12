## Data_layer_Polygons.R
## Step 2 of the DFO Calanus biomass workflow.
## Assigns each depth-integrated grid point to a CINAR region polygon and an
## EcoMon survey stratum using point-in-polygon operations (sf package).
##
## Required packages: dplyr, sf
## Install if needed: install.packages(c("dplyr", "sf"))
##
## Input files (repo root):
##   poly_*.csv          — pre-clipped CINAR polygon boundaries (from export_for_R.m)
##   EMstrata_v4_coords.csv — EcoMon stratum polygon coordinates (from EMstrata_v4.mat)
##   ne_strata_cache.rds — cached sf object built on first run; delete to rebuild
##
## CINAR polygon ID mapping (CINAR_poly column):
##   1 = WSS (Western Scotian Shelf)
##   2 = EGOM (Eastern Gulf of Maine)
##   3 = JB (Jordan Basin)
##   4 = Browns (Browns Bank)
##   5 = Halifax (Eastern Scotian Shelf)
##   6 = GeorgesNEC (Georges Basin and NE Channel)
##   7 = GMB150 (Grand Manan Basin, 150 m isobath)
##   8 = BOF (Bay of Fundy)
##   0 = Unassigned

library(dplyr)
library(sf)

# Use planar (GEOS) geometry instead of spherical (S2).
# S2 rejects polygon files with duplicate consecutive vertices; GEOS tolerates
# them. Planar geometry is appropriate for this regional northwest Atlantic domain.
sf_use_s2(FALSE)

# ===========================================================================
# Configuration
# ===========================================================================

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir   <- getwd()
input_dir  <- file.path(work_dir, "processed")
output_dir <- file.path(work_dir, "polygons")

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Six DFO source regions retained in the analysis
desired_regions <- c("CCB", "Fundy", "GB", "GOM", "SNE", "SS")

# ===========================================================================
# Helper: read a polygon coordinate file into a closed-ring matrix
# ===========================================================================
# All polygon files store coordinates as (lon, lat) with no header.
# Browns_line.txt and Halifax_line.txt are tab-separated; CSVs are comma-separated.
# sf requires the first and last row of each ring to be identical (closed ring).

read_poly <- function(path, sep = ",") {
  df  <- read.table(path, sep = sep, header = FALSE)
  mat <- as.matrix(df[, 1:2])
  colnames(mat) <- c("lon", "lat")
  if (!isTRUE(all.equal(mat[1, ], mat[nrow(mat), ]))) {
    mat <- rbind(mat, mat[1, ])
  }
  mat
}

make_sfc <- function(mat) {
  st_sfc(st_polygon(list(mat)), crs = 4326)
}

# ===========================================================================
# Load pre-clipped CINAR polygon coordinates
# ===========================================================================
# poly_*.csv files are produced by export_for_R.m, which clips each polygon
# against all higher-priority polygons (subtract() in MATLAB).
# Priority order: GMB150 > JB > GeorgesNEC > BOF > WSS > EGOM > Browns > Halifax
# No R-side clipping is needed — the files are already non-overlapping.
# GMB_200 and JB_250 are display-only and excluded from point assignment.

cat("Loading pre-clipped CINAR polygon coordinate files...\n")

cinar_polygons <- st_sf(
  CINAR_poly = c(7L, 3L, 6L, 8L, 1L, 2L, 4L, 5L),
  cinar_name = c("GMB150", "JB", "GeorgesNEC", "BOF", "WSS", "EGOM", "Browns", "Halifax"),
  geometry   = st_sfc(
    make_sfc(read_poly(file.path(work_dir, "data", "poly_GMB_150.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_JB_deep.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_GeorgesNEC.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_BOF_latlon.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_WSS_broad.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_EGOM_broad.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_Browns_line.csv")))[[1]],
    make_sfc(read_poly(file.path(work_dir, "data", "poly_Halifax_line.csv")))[[1]],
    crs = 4326
  )
)

cat(sprintf("CINAR polygon object: %d polygons\n", nrow(cinar_polygons)))

# ===========================================================================
# Load EcoMon strata
# ===========================================================================
# Stratum polygons come from EMstrata_v4_coords.csv, which was exported from
# EMstrata_v4.mat (MATLAB) using the snippet in run_pipeline.R.
# The sf object is cached as ne_strata_cache.rds after the first build.
# Delete ne_strata_cache.rds to force a rebuild from the CSV.

cat("Loading EcoMon strata from EMstrata_v4_coords.csv...\n")

# Reads polygon coordinates exported from EMstrata_v4.mat via the MATLAB snippet
# in the README. Cached as ne_strata_cache.rds after first build.
# Delete ne_strata_cache.rds to force a rebuild.
strata_cache <- file.path(work_dir, "cache", "ne_strata_cache.rds")

if (!file.exists(strata_cache)) {
  coords_file <- file.path(work_dir, "data", "EMstrata_v4_coords.csv")
  if (!file.exists(coords_file)) {
    stop(
      "EMstrata_v4_coords.csv not found.\n",
      "Generate it by running the MATLAB export snippet in the README:\n",
      "  load('EMstrata_v4.mat'); ... writetable(T, 'EMstrata_v4_coords.csv')"
    )
  }
  cat("  Building sf polygons from EMstrata_v4_coords.csv...\n")

  strata_coords <- read.csv(coords_file)

  # Build one sf polygon per stratum index (14-47)
  strata_list <- lapply(split(strata_coords, strata_coords$stratum_id), function(df) {
    mat <- as.matrix(df[, c("lon", "lat")])
    if (!isTRUE(all.equal(mat[1, ], mat[nrow(mat), ]))) mat <- rbind(mat, mat[1, ])
    st_polygon(list(mat))
  })

  ecomon_polygons <- st_sf(
    EcoMon_poly = as.integer(names(strata_list)),
    geometry    = st_sfc(strata_list, crs = 4326)
  )

  saveRDS(ecomon_polygons, strata_cache)
  cat("  Cached to:", strata_cache, "\n")
} else {
  ecomon_polygons <- readRDS(strata_cache)
  cat("  Loaded from local cache.\n")
}

cat(sprintf("Loaded %d EcoMon strata (ID range: %d - %d)\n",
            nrow(ecomon_polygons),
            min(ecomon_polygons$EcoMon_poly),
            max(ecomon_polygons$EcoMon_poly)))

# ===========================================================================
# Process each processed CSV file
# ===========================================================================

csv_files <- list.files(input_dir, pattern = "_processed\\.csv$", full.names = TRUE)
cat(sprintf("\nFound %d processed CSV files\n", length(csv_files)))

for (filepath in csv_files) {
  filename <- basename(filepath)
  cat(sprintf("\n%s\nProcessing: %s\n", strrep("=", 60), filename))

  tryCatch({

    data <- read.csv(filepath)
    cat(sprintf("Loaded: %d rows x %d cols\n", nrow(data), ncol(data)))

    # Check required columns
    missing <- setdiff(c("X", "Y", "REGION"), names(data))
    if (length(missing) > 0) {
      cat(sprintf("Warning: Missing columns: %s. Skipping.\n", paste(missing, collapse = ", ")))
      next
    }

    # Filter to desired regions
    data <- data[data$REGION %in% desired_regions, ]
    cat(sprintf("After region filter: %d rows\n", nrow(data)))
    if (nrow(data) == 0) next

    # Convert to sf points (X = lon, Y = lat; original columns retained)
    pts <- st_as_sf(data, coords = c("X", "Y"), crs = 4326, remove = FALSE)

    # ---- CINAR assignment ------------------------------------------------
    # Non-overlapping clipped geometry means each point matches at most one polygon.
    # Deduplicate by Label as a safeguard against boundary-point double-matches.
    cat("Assigning CINAR polygons...\n")
    pts <- suppressWarnings(st_join(pts, cinar_polygons[, c("CINAR_poly", "cinar_name")],
                                    join = st_within, left = TRUE))
    pts <- pts[!duplicated(pts$Label), ]
    pts$CINAR_poly[is.na(pts$CINAR_poly)] <- 0L
    pts$cinar_name <- NULL

    # ---- EcoMon assignment -----------------------------------------------
    cat("Assigning EcoMon polygons...\n")
    pts <- suppressWarnings(st_join(pts, ecomon_polygons[, "EcoMon_poly"],
                                    join = st_within, left = TRUE))
    pts <- pts[!duplicated(pts$Label), ]
    pts$EcoMon_poly[is.na(pts$EcoMon_poly)] <- 0L

    # Drop sf geometry, return to plain data frame
    result <- st_drop_geometry(pts)

    # ---- Write output ----------------------------------------------------
    base_name <- sub("_processed\\.csv$", "", filename)
    out_file  <- file.path(output_dir, paste0(base_name, "_processed_polygons.csv"))
    write.csv(result, out_file, row.names = FALSE)

    # ---- Summary ---------------------------------------------------------
    n_cinar_assigned   <- sum(result$CINAR_poly > 0)
    n_cinar_unassigned <- sum(result$CINAR_poly == 0)
    n_ecomon_assigned  <- sum(result$EcoMon_poly > 0)

    cat("CINAR polygon assignments:\n")
    for (id in sort(unique(result$CINAR_poly[result$CINAR_poly > 0]))) {
      nm  <- cinar_polygons$cinar_name[cinar_polygons$CINAR_poly == id]
      cnt <- sum(result$CINAR_poly == id)
      cat(sprintf("  %s (%d): %d points\n", nm, id, cnt))
    }
    cat(sprintf("  Unassigned: %d points\n", n_cinar_unassigned))
    cat(sprintf("EcoMon assignments: %d points assigned\n", n_ecomon_assigned))
    cat(sprintf("Saved: %s\n", basename(out_file)))

  }, error = function(e) {
    cat(sprintf("Error processing %s: %s\n", filename, e$message))
  })
}

cat(sprintf("\n%s\nProcessing complete!\n", strrep("=", 60)))
cat(sprintf("Output files saved to: %s\n", output_dir))
