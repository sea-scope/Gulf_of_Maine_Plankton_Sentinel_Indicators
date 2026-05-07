## run_sentinel.R
## Orchestrator for the Sentinel Indicators pipeline.
## Open GoM_Plankton_Sentinel_Indicators.Rproj before running so that
## getwd() resolves to the repo root.

# =============================================================================
# Configuration
# =============================================================================

# Path to the directory containing UBER and MBON Excel files
uber_dir <- "C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/Zoo Lab Data"

# Stations to process
stations <- c("WBTS", "CMTS")

# =============================================================================
# Step 1: Station config
# =============================================================================

source("R/02_sentinel_indicators/station_config.R")

# =============================================================================
# Step 2: Ingest — read raw Excel, write standardized CSVs
# =============================================================================

source("R/02_sentinel_indicators/ingest_station_data.R")

for (stn in stations) {
  cat("\n===== Ingesting", stn, "=====\n")
  ingest_station(stn, source = "excel", uber_dir = uber_dir)
}

# =============================================================================
# Step 3: Prepare — filter, QC, derived variables, seasons
# =============================================================================

source("R/02_sentinel_indicators/prepare_station_data.R")

for (stn in stations) {
  cat("\n===== Preparing", stn, "=====\n")
  prepare_station(stn)
}

# =============================================================================
# Step 4: Analysis (WP4b) — GAMs, baselines, anomalies
# =============================================================================

source("R/02_sentinel_indicators/analyze_station_data.R")

cat("\n===== Fitting GAMs, generating predictions, and saving diagnostics =====\n")
fit_results <- analyze_all_stations(stations = stations)

# =============================================================================
# Step 5: Figures (WP4c) — phenology, seasonal, anomaly plots + metadata JSON
# =============================================================================
# Figure generation is integrated into analyze_all_stations() (Step 4).
# Phenology, seasonal trend, and anomaly time series PNGs are saved to
# plots/sentinel/{station}/. Sentinel metadata JSON is exported to
# plots/sentinel/sentinel_metadata.json.

cat("\n===== Sentinel pipeline complete =====\n")
