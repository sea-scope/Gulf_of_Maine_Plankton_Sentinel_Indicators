## run_spm_biomass.R
## Orchestrator for the SPM Calanus biomass pipeline.
## Open GoM_Plankton_Sentinel_Indicators.Rproj before running so that
## getwd() resolves to the repo root.
##
## Steps 1-4g reproduce the full SPM biomass product:
##   processed/ -> polygons/ -> summaries/ -> plots/ + figures/

source("R/01_spm_biomass/DFO_data_process.R")           # Step 1: RDS -> processed/
source("R/01_spm_biomass/Data_layer_Polygons.R")         # Step 2: processed/ -> polygons/
source("R/01_spm_biomass/DFO_data_polygon_summary.R")    # Step 3: polygons/ -> summaries/

source("R/01_spm_biomass/DFO_biomass_visualization_CINAR.R")   # Step 4a: CINAR biomass plots
source("R/01_spm_biomass/DFO_biomass_visualization_EcoMon.R")  # Step 4b: EcoMon biomass plots

source("R/01_spm_biomass/export_viewer_metadata.R")            # Step 4c: viewer metadata JSON

source("R/01_spm_biomass/DFO_CINAR_polygon_map.R")             # Step 4e: CINAR polygon map
source("R/01_spm_biomass/DFO_EcoMon_strata_map.R")             # Step 4f: EcoMon strata map
source("R/01_spm_biomass/DFO_region_map.R")                    # Step 4g: CINAR + SBNMS region maps

cat("\nSPM biomass pipeline complete. Output files:\n")
cat("  processed/                          -- depth-integrated biomass per grid point\n")
cat("  polygons/                           -- polygon-assigned grid points\n")
cat("  summaries/spm_biomass/              -- DFO_biomass_summary.csv\n")
cat("  plots/spm_biomass/stations_metadata.json -- viewer metadata\n")
cat("  figures/                            -- maps (polygon QC, strata, region)\n")
cat("  plots/spm_biomass/cinar_overview/   -- CINAR all-years-overlaid figures\n")
cat("  plots/spm_biomass/cinar_yearly/     -- CINAR per-year climatology figures\n")
cat("  plots/spm_biomass/ecomon_overview/  -- EcoMon all-years-overlaid figures\n")
cat("  plots/spm_biomass/ecomon_yearly/    -- EcoMon per-year climatology figures\n")
