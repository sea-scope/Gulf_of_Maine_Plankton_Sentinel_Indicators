## DFO_data_process.R
## Step 1 of the DFO Calanus biomass workflow.
## Reads raw 3D Calanus biomass RDS files and integrates biomass over depth layers.
##
## Input:  Bioenergy_3D/*.rds  (one file per month/year, from DFO)
## Output: processed/*_processed.csv  (one file per input RDS)
##
## Depth layers computed per grid point (Label/X/Y) per year/month:
##   Shallow (0-80 m):  sum_cfin_0_80,     sum_cgla_0_80,     sum_chyp_0_80
##   Deep    (>80 m):   sum_cfin_below_80,  sum_cgla_below_80,  sum_chyp_below_80
##   Full column:       sum_cfin_total,     sum_cgla_total,     sum_chyp_total
##
## Species codes:
##   cfin = Calanus finmarchicus
##   cgla = Calanus glacialis
##   chyp = Calanus hyperboreus
##
## Required input columns in each RDS:
##   Zlayer, Label, X, Y, bathymetry, fYear, month, REGION,
##   DW_Zlayer_mg_cfin, DW_Zlayer_mg_cgla, DW_Zlayer_mg_chyp
##
## Required packages: dplyr, tidyr
## Open SPM_calanus_biomass.Rproj before sourcing so getwd() = repo root.

library(dplyr)
library(tidyr)

# Repository root — set automatically from the current working directory.
# Open the .Rproj file (or setwd() to the repo root) before sourcing.
work_dir   <- getwd()
input_dir  <- file.path(work_dir, "Bioenergy_3D")
output_dir <- file.path(work_dir, "processed")

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# List all .rds files in input_dir (case-insensitive)
rds_files <- list.files(input_dir, pattern = "\\.[Rr][Dd][Ss]$", full.names = FALSE)

cat("Found", length(rds_files), "RDS files to process:\n")
print(rds_files)

# Function to process a single dataframe
process_calanus_data <- function(df, file_name) {
  cat("Processing:", file_name, "\n")
  
  # Extract year and month from filename for output naming
  # Assumes filename format like "Bioenergy_YYYY_MM_3D.rds"
  base_name <- tools::file_path_sans_ext(file_name)
  
  # Shallow layer: Zlayer <= 80
  shallow_layer <- df %>%
    filter(Zlayer <= 80) %>%
    group_by(Label, X, Y, bathymetry, fYear, month, REGION) %>%
    summarise(
      sum_cfin_0_80 = sum(DW_Zlayer_mg_cfin, na.rm = TRUE),
      sum_cgla_0_80 = sum(DW_Zlayer_mg_cgla, na.rm = TRUE),
      sum_chyp_0_80 = sum(DW_Zlayer_mg_chyp, na.rm = TRUE),
      .groups = 'drop'
    )
  
  # Deep layer: Zlayer > 80
  deep_layer <- df %>%
    filter(Zlayer > 80) %>%
    group_by(Label, X, Y, bathymetry, fYear, month, REGION) %>%
    summarise(
      sum_cfin_below_80 = sum(DW_Zlayer_mg_cfin, na.rm = TRUE),
      sum_cgla_below_80 = sum(DW_Zlayer_mg_cgla, na.rm = TRUE),
      sum_chyp_below_80 = sum(DW_Zlayer_mg_chyp, na.rm = TRUE),
      .groups = 'drop'
    )

  # Full water column: all Zlayer values (no depth filter)
  total_layer <- df %>%
    group_by(Label, X, Y, bathymetry, fYear, month, REGION) %>%
    summarise(
      sum_cfin_total = sum(DW_Zlayer_mg_cfin, na.rm = TRUE),
      sum_cgla_total = sum(DW_Zlayer_mg_cgla, na.rm = TRUE),
      sum_chyp_total = sum(DW_Zlayer_mg_chyp, na.rm = TRUE),
      .groups = 'drop'
    )

  # Merge all three layers
  processed_data <- full_join(
    shallow_layer,
    deep_layer,
    by = c("Label", "X", "Y", "bathymetry", "fYear", "month", "REGION")
  ) %>%
    left_join(
      total_layer,
      by = c("Label", "X", "Y", "bathymetry", "fYear", "month", "REGION")
    )
  
  return(processed_data)
}

# Process each file in a loop
for (file in rds_files) {
  tryCatch({
    # Read the RDS file
    cat("\n", paste(rep("=", 50), collapse=""), "\n")
    cat("Loading file:", file, "\n")
    
    data_3d <- readRDS(file.path(input_dir, file))
    
    # Check if the dataframe has the required columns
    required_cols <- c("Zlayer", "Label", "X", "Y", "bathymetry", "fYear", "month", "REGION",
                       "DW_Zlayer_mg_cfin", "DW_Zlayer_mg_cgla", "DW_Zlayer_mg_chyp")
    
    missing_cols <- setdiff(required_cols, names(data_3d))
    if (length(missing_cols) > 0) {
      cat("Warning: Missing columns in", file, ":", paste(missing_cols, collapse = ", "), "\n")
      cat("Skipping this file.\n")
      next
    }
    
    # Process the data
    processed_data <- process_calanus_data(data_3d, file)
    
    # Create output filename
    base_name <- tools::file_path_sans_ext(file)
    output_file <- paste0(base_name, "_processed.csv")
    output_path <- file.path(output_dir, output_file)
    
    # Save the processed data as CSV for MATLAB compatibility
    write.csv(processed_data, output_path, row.names = FALSE)
    
    cat("Successfully processed and saved:", output_file, "\n")
    cat("Dimensions:", nrow(processed_data), "rows x", ncol(processed_data), "columns\n")
    
  }, error = function(e) {
    cat("Error processing file", file, ":", e$message, "\n")
  })
}

cat("\n", paste(rep("=", 50), collapse=""), "\n")
cat("Processing complete!\n")
cat("Processed files saved to:", output_dir, "\n")

# Optional: Create a summary of processed files
processed_files <- list.files(output_dir, pattern = "_processed\\.csv$")
cat("Total processed files:", length(processed_files), "\n")

# Optional: Quick check of one processed file
if (length(processed_files) > 0) {
  cat("\nSample of processed data structure:\n")
  sample_file <- file.path(output_dir, processed_files[1])
  sample_data <- read.csv(sample_file)
  cat("Sample file:", processed_files[1], "\n")
  cat("Columns:", paste(names(sample_data), collapse = ", "), "\n")
  cat("First few rows:\n")
  print(head(sample_data, 3))
}
