# =============================================================================
# Sentinel Indicators — Data Ingest Layer
#
# Reads raw data from source(s) and writes a standardized long-format CSV
# to data/sentinel/raw/{station_id}_raw.csv.
#
# The output has consistent column names regardless of source, so that the
# preparation layer never needs to know where the data came from.
#
# Supported sources:
#   "excel"  — UBER zoobio vertical Excel files (OneDrive)
#   "erddap" — stub, not yet implemented
#
# MBON supplement (CMTS only):
#   When station config has mbon_source = TRUE, the ingest function also
#   reads the MBON Zoop Counts Excel and appends those rows. MBON data
#   has #/m3 units — converted to #/m2 by multiplying by station depth.
#   MBON data has no DW, biomass flag, or counts flag columns.
# =============================================================================

library(readxl)
library(dplyr)

# Source station config if not already loaded
if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# -----------------------------------------------------------------------------
# Standardized column names for raw output
# -----------------------------------------------------------------------------

raw_columns <- c(
  "DATE", "Net_Depth", "DW_g_m2", "Sample_Type", "Biomass_Flag",
  "Station", "Counts_Flag",
  "Cfin_CI_m2", "Cfin_CII_m2", "Cfin_CIII_m2", "Cfin_CIV_m2",
  "Cfin_CV_m2", "Cfin_F_m2", "Cfin_M_m2",
  "source"
)

# -----------------------------------------------------------------------------
# UBER Excel column names (as they appear in the spreadsheets)
# -----------------------------------------------------------------------------

uber_columns <- c(
  "DATE", "Net Depth", "Net Depth g-DW/m2", "Sample Type", "Biomass Flag",
  "Station", "Counts Flag",
  "Calanus_finmarchicusCI/M2", "Calanus_finmarchicusCII/M2",
  "Calanus_finmarchicusCIII/M2", "Calanus_finmarchicusCIV/M2",
  "Calanus_finmarchicusCV/M2", "Calanus_finmarchicusF/M2",
  "Calanus_finmarchicusM/M2"
)

# =============================================================================
# ingest_station()
#
# Parameters:
#   station_id  — "WBTS" or "CMTS" (must match a key in station_config)
#   source      — "excel" (default) or "erddap" (stub)
#   uber_dir    — directory containing UBER Excel files
#   uber_files  — named vector of UBER filenames (pre-2018 and current)
#   mbon_dir    — directory containing MBON Excel file (only used if
#                 station config has mbon_source = TRUE)
#   mbon_file   — MBON filename
#   output_dir  — where to write the raw CSV (default: data/sentinel/raw)
#
# Returns: path to the written CSV (invisibly)
# =============================================================================

ingest_station <- function(
    station_id,
    source = "excel",
    uber_dir,
    uber_files = c(
      pre2018 = "UBER_zoobio_vertical_2002_2017.xlsx",
      current = "UBER_zoobio_vertical_2018_current.xlsx"
    ),
    mbon_dir    = uber_dir,
    mbon_file   = "2025 MBON Zoop Counts.xlsx",
    output_dir  = file.path("data", "sentinel", "raw")
) {

  cfg <- station_config[[station_id]]
  if (is.null(cfg)) stop("Unknown station_id: ", station_id)

  if (source == "excel") {
    raw_data <- ingest_from_excel(cfg, uber_dir, uber_files, mbon_dir, mbon_file)
  } else if (source == "erddap") {
    # -----------------------------------------------------------------
    # TODO: ERDDAP ingest
    #
    # Target datasets (when available and up-to-date):
    #   - WBTS: ERDDAP dataset for WB-7 vertical zooplankton tows
    #   - CMTS: ERDDAP dataset for DMC-2 vertical zooplankton tows
    #
    # Implementation notes:
    #   - Use rerddap package to query by station, date range
    #   - Map ERDDAP variable names to the standardized raw_columns
    #   - The output format must match the Excel ingest exactly so
    #     that prepare_station() works without changes
    #   - Coordinate with data managers (Jeff Runge, Cameron Thompson)
    #     on dataset IDs and variable naming before implementing
    # -----------------------------------------------------------------
    stop("ERDDAP source not yet implemented. See TODO in ingest_station_data.R.")
  } else {
    stop("Unknown source: ", source, ". Use 'excel' or 'erddap'.")
  }

  # Write output
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(output_dir, paste0(station_id, "_raw.csv"))
  write.csv(raw_data, out_path, row.names = FALSE)
  cat("Wrote", nrow(raw_data), "rows to", out_path, "\n")

  invisible(out_path)
}

# =============================================================================
# ingest_from_excel() — internal function
# =============================================================================

ingest_from_excel <- function(cfg, uber_dir, uber_files, mbon_dir, mbon_file) {

  # --- Read UBER data ---
  cat("Reading UBER Excel files for", cfg$station_id, "...\n")

  df_pre <- read_excel(file.path(uber_dir, uber_files["pre2018"]))
  df_cur <- read_excel(file.path(uber_dir, uber_files["current"]))

  df_pre <- df_pre %>% dplyr::select(all_of(uber_columns))
  df_cur <- df_cur %>% dplyr::select(all_of(uber_columns))
  uber_data <- bind_rows(df_pre, df_cur)

  # Standardize column names
  names(uber_data) <- raw_columns[1:14]
  uber_data$source <- "UBER"

  # Convert DATE to character ISO format for CSV storage
  uber_data$DATE <- as.character(as.Date(uber_data$DATE))

  cat("  UBER total rows:", nrow(uber_data), "\n")

  # --- Read MBON data (if configured) ---
  if (isTRUE(cfg$mbon_source)) {
    cat("Reading MBON Excel for", cfg$station_id, "...\n")

    mbon_raw <- read_excel(file.path(mbon_dir, mbon_file),
                           sheet = 1, col_names = FALSE, skip = 7)

    # Filter for this station, drop rows with invalid dates
    mbon_filtered <- mbon_raw %>%
      filter(!is.na(.[[4]]),
             .[[4]] == cfg$mbon_station_code,
             .[[1]] > 0)

    # Extract depth for unit conversion (#/m3 -> #/m2)
    mbon_depth <- as.numeric(mbon_filtered[[5]])

    # Parse yyyymmdd date
    mbon_date <- as.character(as.Date(as.character(mbon_filtered[[1]]),
                                      format = "%Y%m%d"))

    # Build standardized data frame
    mbon_data <- data.frame(
      DATE         = mbon_date,
      Net_Depth    = NA_real_,
      DW_g_m2      = NA_real_,
      Sample_Type  = NA_character_,
      Biomass_Flag = NA_real_,
      Station      = cfg$station_code,  # Map to UBER station code
      Counts_Flag  = NA_real_,
      Cfin_CI_m2   = as.numeric(mbon_filtered[[17]]) * mbon_depth,
      Cfin_CII_m2  = as.numeric(mbon_filtered[[18]]) * mbon_depth,
      Cfin_CIII_m2 = as.numeric(mbon_filtered[[19]]) * mbon_depth,
      Cfin_CIV_m2  = as.numeric(mbon_filtered[[20]]) * mbon_depth,
      Cfin_CV_m2   = as.numeric(mbon_filtered[[21]]) * mbon_depth,
      Cfin_F_m2    = as.numeric(mbon_filtered[[22]]) * mbon_depth,
      Cfin_M_m2    = as.numeric(mbon_filtered[[23]]) * mbon_depth,
      source       = "MBON",
      stringsAsFactors = FALSE
    )

    cat("  MBON rows:", nrow(mbon_data), "\n")

    uber_data <- bind_rows(uber_data, mbon_data)
  }

  cat("  Combined rows:", nrow(uber_data), "\n")
  return(uber_data)
}
