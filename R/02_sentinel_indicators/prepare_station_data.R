# =============================================================================
# Sentinel Indicators — Data Preparation Layer
#
# Reads data/sentinel/raw/{station_id}_raw.csv, applies QC and filtering,
# computes derived indices (CI, CSI, DW), assigns seasons, and writes
# data/sentinel/prepared/{station_id}_prepared.csv.
#
# This layer never touches raw Excel files — it works only from the
# standardized CSV produced by the ingest layer.
#
# =============================================================================
# Column reference for the prepared output:
#
#   DATE          — sample date (ISO format, character)
#   day_of_year   — integer 1–365
#   year          — integer
#   season        — "spring", "summer", "fall", or "winter"
#   Net_Depth     — net tow depth (m), from UBER; NA for MBON rows
#   Station       — station code (e.g. "WB-7", "DMC-2")
#   source        — data source ("UBER" or "MBON")
#   CI            — Calanus Index: sum of CIII + CIV + CV + F + M (#/m2)
#                   Set to NA where Counts_Flag == 1
#   CSI           — Copepodite Stage Index: abundance-weighted mean stage
#                   (1–6 scale). Set to NA where Counts_Flag == 1 or
#                   total abundance is zero. Not transformed here.
#   DW            — Dry Weight (g/m2): net-depth-integrated zooplankton
#                   biomass. Set to NA where Biomass_Flag == 1.
#                   Not transformed here — sqrt is applied in the analysis
#                   layer (WP4b) because the transform is part of the model
#                   specification, not data cleaning.
#   Cfin_CI_m2 .. Cfin_M_m2  — individual stage abundances (#/m2),
#                   retained for reference/QC
#
# Quality flags:
#   Biomass_Flag == 1  →  DW set to NA (sample compromised for biomass)
#   Counts_Flag  == 1  →  CI and CSI set to NA (counts unreliable)
#   These flags come from the UBER source. MBON rows have NA flags,
#   meaning all MBON data passes through (no flags available).
#
# Transforms:
#   sqrt(CI) and sqrt(DW) are NOT applied here. They are part of the
#   GAM model specification and are applied in the analysis layer (WP4b).
#   The prepared CSV stores natural-scale values so that any downstream
#   analysis can choose its own transform.
# =============================================================================

library(dplyr)
library(lubridate)

# Source station config if not already loaded
if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# prepare_station()
#
# Parameters:
#   station_id  — "WBTS" or "CMTS" (must match a key in station_config)
#   input_dir   — where to find raw CSVs (default: data/sentinel/raw)
#   output_dir  — where to write prepared CSVs (default: data/sentinel/prepared)
#
# Returns: path to the written CSV (invisibly)
# =============================================================================

prepare_station <- function(
    station_id,
    input_dir  = file.path("data", "sentinel", "raw"),
    output_dir = file.path("data", "sentinel", "prepared")
) {

  cfg <- station_config[[station_id]]
  if (is.null(cfg)) stop("Unknown station_id: ", station_id)

  # -------------------------------------------------------------------------
  # Read raw CSV
  # -------------------------------------------------------------------------

  raw_path <- file.path(input_dir, paste0(station_id, "_raw.csv"))
  if (!file.exists(raw_path)) {
    stop("Raw CSV not found: ", raw_path,
         "\nRun ingest_station('", station_id, "') first.")
  }

  data <- read.csv(raw_path, stringsAsFactors = FALSE)
  cat("Read", nrow(data), "rows from", raw_path, "\n")

  # -------------------------------------------------------------------------
  # Filter by station code
  # -------------------------------------------------------------------------

  data <- data %>% filter(Station == cfg$station_code)
  cat("  After station filter (", cfg$station_code, "):", nrow(data), "rows\n")

  # -------------------------------------------------------------------------
  # Filter by deep tow depth (station-specific, NULL = no filter)
  # -------------------------------------------------------------------------

  if (!is.null(cfg$deep_tow_min)) {
    data <- data %>% filter(Net_Depth >= cfg$deep_tow_min)
    cat("  After deep-tow filter (>=", cfg$deep_tow_min, "m):",
        nrow(data), "rows\n")
  }

  # -------------------------------------------------------------------------
  # Exclude ETOH samples
  # -------------------------------------------------------------------------

  data <- data %>% filter(is.na(Sample_Type) | Sample_Type != "ETOH")
  cat("  After ETOH exclusion:", nrow(data), "rows\n")

  # -------------------------------------------------------------------------
  # Date processing
  # -------------------------------------------------------------------------

  data$DATE <- as.character(as.Date(data$DATE))
  data$day_of_year <- yday(as.Date(data$DATE))
  data$year <- year(as.Date(data$DATE))

  # -------------------------------------------------------------------------
  # Compute derived quantities
  # -------------------------------------------------------------------------

  # Calanus Index: CIII through adult (#/m2)
  data$CI <- data$Cfin_CIII_m2 + data$Cfin_CIV_m2 +
    data$Cfin_CV_m2 + data$Cfin_F_m2 + data$Cfin_M_m2

  # Total CI-Adult abundance (for CSI denominator)
  total_abund <- data$Cfin_CI_m2 + data$Cfin_CII_m2 +
    data$Cfin_CIII_m2 + data$Cfin_CIV_m2 +
    data$Cfin_CV_m2 + data$Cfin_F_m2 + data$Cfin_M_m2

  # Copepodite Stage Index: abundance-weighted mean stage (1–6)
  stage_weighted <- data$Cfin_CI_m2 * 1 + data$Cfin_CII_m2 * 2 +
    data$Cfin_CIII_m2 * 3 + data$Cfin_CIV_m2 * 4 +
    data$Cfin_CV_m2 * 5 +
    (data$Cfin_F_m2 + data$Cfin_M_m2) * 6

  data$CSI <- ifelse(total_abund > 0, stage_weighted / total_abund, NA_real_)

  # Dry Weight (g/m2)
  data$DW <- data$DW_g_m2

  # -------------------------------------------------------------------------
  # Apply quality flags
  # -------------------------------------------------------------------------

  # Biomass flag: flag == 1 invalidates DW
  data$DW[!is.na(data$Biomass_Flag) & data$Biomass_Flag == 1] <- NA

  # Counts flag: flag == 1 invalidates CI and CSI
  data$CI[!is.na(data$Counts_Flag) & data$Counts_Flag == 1] <- NA
  data$CSI[!is.na(data$Counts_Flag) & data$Counts_Flag == 1] <- NA

  # -------------------------------------------------------------------------
  # Assign seasons (station-specific boundaries from config)
  # -------------------------------------------------------------------------

  data <- assign_seasons(data, cfg)
  cat("  Season counts:\n")
  print(table(data$season, useNA = "ifany"))

  # -------------------------------------------------------------------------
  # Select and order output columns
  # -------------------------------------------------------------------------

  out_cols <- c("DATE", "day_of_year", "year", "season",
                "Net_Depth", "Station", "source",
                "CI", "CSI", "DW",
                "Cfin_CI_m2", "Cfin_CII_m2", "Cfin_CIII_m2",
                "Cfin_CIV_m2", "Cfin_CV_m2", "Cfin_F_m2", "Cfin_M_m2")

  data <- data[, out_cols]

  # -------------------------------------------------------------------------
  # Write output
  # -------------------------------------------------------------------------

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(output_dir, paste0(station_id, "_prepared.csv"))
  write.csv(data, out_path, row.names = FALSE)
  cat("Wrote", nrow(data), "rows to", out_path, "\n")

  invisible(out_path)
}

# =============================================================================
# assign_seasons() — internal function
#
# Handles both 4-season (WBTS) and 3-season (CMTS) configurations.
# For 3-season configs, the "winter" season wraps across the year boundary
# (e.g. DOY 248–365 and DOY 1–73).
# =============================================================================

assign_seasons <- function(data, cfg) {
  bounds <- cfg$season_boundaries
  doy <- data$day_of_year

  if (cfg$n_seasons == 4) {
    # 4 seasons: spring, summer, fall, winter — no wrapping needed
    data$season <- case_when(
      doy >= bounds$spring[1] & doy <= bounds$spring[2] ~ "spring",
      doy >= bounds$summer[1] & doy <= bounds$summer[2] ~ "summer",
      doy >= bounds$fall[1]   & doy <= bounds$fall[2]   ~ "fall",
      doy >= bounds$winter[1] & doy <= bounds$winter[2] ~ "winter",
      TRUE ~ NA_character_
    )
  } else if (cfg$n_seasons == 3) {
    # 3 seasons: spring, summer, winter (winter wraps year boundary)
    # Winter boundary stored as c(start, end) where start > end means wrap
    data$season <- case_when(
      doy >= bounds$spring[1] & doy <= bounds$spring[2] ~ "spring",
      doy >= bounds$summer[1] & doy <= bounds$summer[2] ~ "summer",
      doy >= bounds$winter[1] | doy <= bounds$winter[2] ~ "winter",
      TRUE ~ NA_character_
    )
  } else {
    stop("Unsupported n_seasons: ", cfg$n_seasons)
  }

  return(data)
}
