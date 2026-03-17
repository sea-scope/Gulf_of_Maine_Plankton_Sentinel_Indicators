# Gulf of Maine Plankton Sentinel Indicators

Interactive visualization of *Calanus finmarchicus* biomass across the Northwest Atlantic shelf, derived from the DFO Species Distribution Model (SDM) data product (Plourde et al. 2024).

**Live site:** [sea-scope.github.io/Gulf_of_Maine_Plankton_Sentinel_Indicators](https://sea-scope.github.io/Gulf_of_Maine_Plankton_Sentinel_Indicators/)

## Overview

This repository provides an R data pipeline and static web viewer for exploring modeled *C. finmarchicus* biomass (CIV–CVI stages) at regional spatial scales. Biomass fields from the DFO GLORYS12v1-based SDM (~9 km resolution) are aggregated into CINAR polygons and NOAA EcoMon survey strata, summarized by depth layer (0–80 m, >80 m, total), and visualized as seasonal climatologies with interannual context.

The web viewer presents three perspectives:

| Page | Scope |
|------|-------|
| **CINAR** | 8 CINAR regional polygons (Bay of Fundy, WSS, Halifax, Browns, Georges/NEC, EGOM, GMB150, Jordans Basin) |
| **EcoMon** | All 33 EcoMon survey strata in the study domain |
| **CPO** | Stellwagen Bank NMS + EcoMon strata 35, 36, 37, 40 |

## Data Pipeline

The pipeline is orchestrated by `run_pipeline.R`. Open `SPM_calanus_biomass.Rproj` before running.

| Step | Script | Description |
|------|--------|-------------|
| 1 | `R/DFO_data_process.R` | Read raw 3D biomass RDS files, integrate over depth layers, write CSVs |
| 2 | `R/Data_layer_Polygons.R` | Assign grid points to CINAR polygons and EcoMon strata (point-in-polygon) |
| 3 | `R/DFO_data_polygon_summary.R` | Aggregate to polygon-level means, SDs, ranges, bathymetry stats, sample sizes |
| 4a | `R/DFO_biomass_visualization_CINAR.R` | Generate CINAR biomass plots (overview + per-year climatology) |
| 4b | `R/DFO_biomass_visualization_EcoMon.R` | Generate EcoMon biomass plots (overview + per-year climatology) |
| 4c | `R/export_viewer_metadata.R` | Export viewer metadata JSON |
| 4e | `R/DFO_CINAR_polygon_map.R` | CINAR polygon QC map |
| 4f | `R/DFO_EcoMon_strata_map.R` | EcoMon strata map |
| 4g | `R/DFO_region_map.R` | Publication-quality region maps |

### Input data

Raw SDM output files (`Bioenergy_3D/*.rds`) are not included in this repository (~8.8 GB). Contact DFO (Caroline Lehoux, Eve Rioux) for access to the *C. finmarchicus* biomass data product, or see Plourde et al. (2024) for details.

### Output structure

```
plots/
  stations_metadata.json        -- viewer metadata
  cinar_overview/               -- CINAR all-years-overlaid PNGs
  cinar_yearly/                 -- CINAR per-year climatology PNGs
  ecomon_overview/              -- EcoMon all-years-overlaid PNGs
  ecomon_yearly/                -- EcoMon per-year climatology PNGs
figures/
  DFO_region_map_CINAR.png     -- CINAR publication map
  DFO_region_map_SBNMS.png     -- SBNMS/GoM region map
  EcoMon_strata_map.png        -- EcoMon strata map
summaries/
  DFO_biomass_summary.csv      -- polygon-level summary statistics
```

## How to Read the Plots

Each per-year figure has four layers:

| Layer | Description |
|-------|-------------|
| Light grey ribbon | Historical range (min–max across all years) |
| Dark grey ribbon | Climatological mean ± 1 SD |
| Dashed grey line | Climatological mean |
| Orange line + error bars | Selected year mean ± 1 SD |

Months with fewer than 22 data points display a "limited data" placeholder instead of the plot.

## Key Parameters

- **Biomass units:** g m⁻²
- **SDM resolution:** GLORYS12v1, ~9 km (0.083° x 0.083°)
- **Depth layers:** 0–80 m (shallow), >80 m (deep), total water column
- **Species/stages:** *Calanus finmarchicus* CIV–CVI
- **Years:** 1999–2024

## References

Plourde, S., Lehoux, C., Rioux, E., and Galbraith, P.S. (2024). Describing the seasonal and spatial distribution of four key copepod species of the Northwest Atlantic using a species distribution model. DFO Canadian Science Advisory Secretariat Research Document 2024/039.

## Development

This repository and web viewer were developed using Visual Studio Code with Claude Code (Anthropic). Pipeline scripts are written in R using `sf`, `ggplot2`, `marmap`, and `dplyr`.

**Author:** Cameron Thompson, NERACOOS
