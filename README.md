# Gulf of Maine Plankton Sentinel Indicators

Interactive visualization of Gulf of Maine plankton data products, including modeled *Calanus finmarchicus* biomass and sentinel station indicators.

**Live site:** [sea-scope.github.io/Gulf_of_Maine_Plankton_Sentinel_Indicators](https://sea-scope.github.io/Gulf_of_Maine_Plankton_Sentinel_Indicators/)

## Data Products

| Product | Description | Status |
|---------|-------------|--------|
| **SPM Biomass** | Modeled *C. finmarchicus* biomass (CIV-CVI) from DFO GLORYS12v1-based SDM, aggregated into CINAR polygons and EcoMon strata | Complete |
| **Sentinel Indicators** | WBTS/CMTS station time series: Calanus abundance, stage index, mesozooplankton biomass | In development |
| **Environmental Time Series** | Placeholder | Future |
| **Satellite SST/Chl** | Placeholder | Future |

## Repository Structure

```
GoM_Plankton_Sentinel_Indicators/
  GoM_Plankton_Sentinel_Indicators.Rproj  -- R project file (open first)
  run_pipeline.R              -- Master orchestrator (all products)
  run_spm_biomass.R           -- SPM biomass pipeline (Steps 1-4g)
  run_sentinel.R              -- Sentinel indicators pipeline (stub)
  R/
    01_spm_biomass/           -- SPM biomass processing and visualization
    02_sentinel_indicators/   -- Sentinel indicator pipeline (WP4a-c)
    03_environmental_timeseries/  -- Future
    04_satellite_products/    -- Future
    shared/                   -- Shared utilities (populated when needed)
  data/
    spm_biomass/              -- Polygon boundaries, strata coordinates
    sentinel/
      raw/                    -- Raw station Excel files (gitignored)
      prepared/               -- Cleaned station CSVs (committed)
  summaries/
    spm_biomass/              -- DFO_biomass_summary.csv
    sentinel/                 -- Sentinel summary outputs
  plots/
    spm_biomass/              -- SPM biomass viewer plots + metadata JSON
    sentinel/                 -- Sentinel indicator plots
  figures/                    -- Publication maps (shared across products)
  index.html                  -- Landing page
  cinar.html                  -- CINAR viewer
  ecomon.html                 -- EcoMon viewer
  cpo.html                    -- CPO viewer
```

## SPM Biomass Pipeline

The SPM biomass pipeline is orchestrated by `run_spm_biomass.R`.

| Step | Script | Description |
|------|--------|-------------|
| 1 | `R/01_spm_biomass/DFO_data_process.R` | Read raw 3D biomass RDS files, integrate over depth layers |
| 2 | `R/01_spm_biomass/Data_layer_Polygons.R` | Assign grid points to CINAR polygons and EcoMon strata |
| 3 | `R/01_spm_biomass/DFO_data_polygon_summary.R` | Aggregate to polygon-level statistics |
| 4a | `R/01_spm_biomass/DFO_biomass_visualization_CINAR.R` | CINAR biomass plots |
| 4b | `R/01_spm_biomass/DFO_biomass_visualization_EcoMon.R` | EcoMon biomass plots |
| 4c | `R/01_spm_biomass/export_viewer_metadata.R` | Viewer metadata JSON |
| 4e | `R/01_spm_biomass/DFO_CINAR_polygon_map.R` | CINAR polygon QC map |
| 4f | `R/01_spm_biomass/DFO_EcoMon_strata_map.R` | EcoMon strata map |
| 4g | `R/01_spm_biomass/DFO_region_map.R` | Publication-quality region maps |

### Input data

Raw SDM output files (`Bioenergy_3D/*.rds`) are not included (~8.8 GB). Contact DFO (Caroline Lehoux, Eve Rioux) for access.

## How to Read the Plots

Each per-year figure has four layers:

| Layer | Description |
|-------|-------------|
| Light grey ribbon | Historical range (min-max across all years) |
| Dark grey ribbon | Climatological mean +/- 1 SD |
| Dashed grey line | Climatological mean |
| Orange line + error bars | Selected year mean +/- 1 SD |

Months with fewer than 22 data points display a "limited data" placeholder.

## References

Plourde, S., et al. (2024). Calanus species distribution models and NARW foraging habitat in Canadian waters. DFO CSAS Research Document 2024/039.

## Development

Developed using Visual Studio Code with Claude Code (Anthropic). Pipeline scripts are written in R using `sf`, `ggplot2`, `marmap`, and `dplyr`.

**Author:** Cameron Thompson, NERACOOS
