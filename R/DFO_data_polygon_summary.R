## DFO_data_polygon_summary.R
## Step 3 of the DFO Calanus biomass workflow.
## Aggregates point-level biomass to polygon-level statistics (mean, SD, min, max)
## by year and month. Combines CINAR and EcoMon assignments into a single output file.
##
## Input:  polygons/*_processed_polygons.csv
## Output: summaries/DFO_biomass_summary.csv
##
## Output structure (one row per polygon × year × month):
##   polygon        — CINAR name ("WSS","EGOM","JB","Browns","Halifax",
##                    "GeorgesNEC","GMB150","BOF","SBNMS") or "ecomon_<id>"
##   n_observations — number of model grid points in that cell
##   n_0_80         — number of grid points with non-NA shallow (0-80 m) biomass
##   n_below_80     — number of grid points with non-NA deep (>80 m) biomass
##   mean/sd/min/max_cfin_0_80      — C. finmarchicus shallow 0-80 m (mg/m²)
##   mean/sd/min/max_cfin_below_80  — C. finmarchicus deep >80 m (mg/m²)
##   mean/sd/min/max_cfin_total     — C. finmarchicus full column (mg/m²)
##   (same set of columns for cgla = C. glacialis, chyp = C. hyperboreus)
##   mean_bathy, sd_bathy           — bathymetry (m) of grid points in the polygon
##
## Notes:
##   - Rows with poly_id == 0 (no polygon assignment) are excluded.
##   - Inf/-Inf from empty min()/max() groups are replaced with NA.
##   - All numeric columns except n_observations are rounded to 3 decimal places.
##
## Required packages: dplyr
## Open SPM_calanus_biomass.Rproj before sourcing so getwd() = repo root.

library(dplyr)

rm(list = ls())

# Repository root — open the .Rproj file before sourcing.
work_dir   <- getwd()
input_dir  <- file.path(work_dir, "polygons")
output_dir <- file.path(work_dir, "summaries")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# CINAR polygon ID → name lookup
cinar_names <- c("1" = "WSS", "2" = "EGOM", "3" = "JB", "4" = "Browns",
                 "5" = "Halifax", "6" = "GeorgesNEC", "7" = "GMB150", "8" = "BOF",
                 "9" = "SBNMS")

biomass_cols <- c("sum_cfin_0_80", "sum_cgla_0_80", "sum_chyp_0_80",
                  "sum_cfin_below_80", "sum_cgla_below_80", "sum_chyp_below_80",
                  "sum_cfin_total", "sum_cgla_total", "sum_chyp_total")

required_cols <- c("fYear", "month", "bathymetry", "EcoMon_poly", "CINAR_poly", biomass_cols)

# ---------------------------------------------------------------------------
polygon_files <- list.files(input_dir, pattern = "_polygons\\.csv$", full.names = FALSE)
cat("Found", length(polygon_files), "polygon files to process\n")

# Summarise one polygon type per file; returns tidy rows with a 'polygon' label.
# Rows with poly_id == 0 (no assignment) are dropped before aggregation.
# Inf/-Inf arise when min()/max() receive an all-NA group; replaced with NA.
summarise_poly <- function(data, poly_col, label_fn) {
  data %>%
    filter(.data[[poly_col]] > 0) %>%
    group_by(fYear, month, poly_id = .data[[poly_col]]) %>%
    summarise(
      n_observations     = n(),
      n_0_80             = sum(!is.na(sum_cfin_0_80)),
      n_below_80         = sum(!is.na(sum_cfin_below_80)),
      mean_bathy         = mean(bathymetry,         na.rm = TRUE),
      sd_bathy           = sd(bathymetry,           na.rm = TRUE),
      mean_cfin_0_80     = mean(sum_cfin_0_80,     na.rm = TRUE),
      sd_cfin_0_80       = sd(sum_cfin_0_80,       na.rm = TRUE),
      min_cfin_0_80      = min(sum_cfin_0_80,       na.rm = TRUE),
      max_cfin_0_80      = max(sum_cfin_0_80,       na.rm = TRUE),
      mean_cgla_0_80     = mean(sum_cgla_0_80,     na.rm = TRUE),
      sd_cgla_0_80       = sd(sum_cgla_0_80,       na.rm = TRUE),
      min_cgla_0_80      = min(sum_cgla_0_80,       na.rm = TRUE),
      max_cgla_0_80      = max(sum_cgla_0_80,       na.rm = TRUE),
      mean_chyp_0_80     = mean(sum_chyp_0_80,     na.rm = TRUE),
      sd_chyp_0_80       = sd(sum_chyp_0_80,       na.rm = TRUE),
      min_chyp_0_80      = min(sum_chyp_0_80,       na.rm = TRUE),
      max_chyp_0_80      = max(sum_chyp_0_80,       na.rm = TRUE),
      mean_cfin_below_80 = mean(sum_cfin_below_80, na.rm = TRUE),
      sd_cfin_below_80   = sd(sum_cfin_below_80,   na.rm = TRUE),
      min_cfin_below_80  = min(sum_cfin_below_80,   na.rm = TRUE),
      max_cfin_below_80  = max(sum_cfin_below_80,   na.rm = TRUE),
      mean_cgla_below_80 = mean(sum_cgla_below_80, na.rm = TRUE),
      sd_cgla_below_80   = sd(sum_cgla_below_80,   na.rm = TRUE),
      min_cgla_below_80  = min(sum_cgla_below_80,   na.rm = TRUE),
      max_cgla_below_80  = max(sum_cgla_below_80,   na.rm = TRUE),
      mean_chyp_below_80 = mean(sum_chyp_below_80, na.rm = TRUE),
      sd_chyp_below_80   = sd(sum_chyp_below_80,   na.rm = TRUE),
      min_chyp_below_80  = min(sum_chyp_below_80,   na.rm = TRUE),
      max_chyp_below_80  = max(sum_chyp_below_80,   na.rm = TRUE),
      mean_cfin_total    = mean(sum_cfin_total,    na.rm = TRUE),
      sd_cfin_total      = sd(sum_cfin_total,      na.rm = TRUE),
      min_cfin_total     = min(sum_cfin_total,      na.rm = TRUE),
      max_cfin_total     = max(sum_cfin_total,      na.rm = TRUE),
      mean_cgla_total    = mean(sum_cgla_total,    na.rm = TRUE),
      sd_cgla_total      = sd(sum_cgla_total,      na.rm = TRUE),
      min_cgla_total     = min(sum_cgla_total,      na.rm = TRUE),
      max_cgla_total     = max(sum_cgla_total,      na.rm = TRUE),
      mean_chyp_total    = mean(sum_chyp_total,    na.rm = TRUE),
      sd_chyp_total      = sd(sum_chyp_total,      na.rm = TRUE),
      min_chyp_total     = min(sum_chyp_total,      na.rm = TRUE),
      max_chyp_total     = max(sum_chyp_total,      na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      polygon = label_fn(poly_id),
      across(where(is.numeric), ~ifelse(is.infinite(.x), NA_real_, .x)),
      across(where(is.numeric) & !matches("^(n_observations|n_0_80|n_below_80)$"), ~round(.x, 3))
    ) %>%
    select(fYear, month, polygon, n_observations, everything(), -poly_id)
}

# ---------------------------------------------------------------------------
all_summaries <- data.frame()

for (file in polygon_files) {
  tryCatch({
    cat("Processing:", file, "\n")
    d <- read.csv(file.path(input_dir, file))

    missing <- setdiff(required_cols, names(d))
    if (length(missing) > 0) {
      cat("  Skipping — missing columns:", paste(missing, collapse = ", "), "\n")
      next
    }

    ecomon_rows <- summarise_poly(d, "EcoMon_poly",
                                  function(id) paste0("ecomon_", id))
    cinar_rows  <- summarise_poly(d, "CINAR_poly",
                                  function(id) cinar_names[as.character(id)])

    all_summaries <- bind_rows(all_summaries, ecomon_rows, cinar_rows)
    cat("  EcoMon rows:", nrow(ecomon_rows),
        "| CINAR rows:", nrow(cinar_rows), "\n")

  }, error = function(e) {
    cat("  Error processing", file, ":", e$message, "\n")
  })
}

# ---------------------------------------------------------------------------
output_path <- file.path(output_dir, "DFO_biomass_summary.csv")
write.csv(all_summaries, output_path, row.names = FALSE)

cat("\nDone.\n")
cat("  Total rows   :", nrow(all_summaries), "\n")
cat("  Years        :", min(all_summaries$fYear, na.rm = TRUE), "-",
                        max(all_summaries$fYear, na.rm = TRUE), "\n")
cat("  Polygons     :", paste(sort(unique(all_summaries$polygon)), collapse = ", "), "\n")
cat("  Saved to     :", output_path, "\n")
