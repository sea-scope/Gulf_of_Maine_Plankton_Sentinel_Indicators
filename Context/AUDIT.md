# Repository Audit: Gulf of Maine Plankton Sentinel Indicators

**Audited by:** Claude (Opus 4.6)
**Date:** 2026-03-12
**Repository:** `C:\Users\camer\Desktop\SPM_calanus_biomass`
**GitHub:** https://github.com/sea-scope/Gulf_of_Maine_Plankton_Sentinel_Indicators

---

## Table of Contents

1. [Pipeline Overview](#1-pipeline-overview)
2. [R Script Reference](#2-r-script-reference)
3. [MATLAB Script Reference](#3-matlab-script-reference)
4. [Data File Reference](#4-data-file-reference)
5. [Summary File Reference](#5-summary-file-reference)
6. [Figure Reference](#6-figure-reference)
7. [Cache File Reference](#7-cache-file-reference)
8. [Bugs and Inconsistencies](#8-bugs-and-inconsistencies)

---

## 1. Pipeline Overview

The pipeline processes DFO 3D Calanus biomass model output into polygon-level summary
statistics and visualization figures. It is orchestrated by `run_pipeline.R`, which
sources Steps 1 through 4g sequentially.

```
[Step 1]  R/DFO_data_process.R
            Bioenergy_3D/*.rds  -->  processed/*_processed.csv

[Step 2]  R/Data_layer_Polygons.R
            processed/*.csv + data/poly_*.csv + data/EMstrata_v4_coords.csv
            -->  polygons/*_processed_polygons.csv

[Step 3]  R/DFO_data_polygon_summary.R
            polygons/*.csv  -->  summaries/DFO_biomass_summary.csv

[Step 4a] R/DFO_biomass_visualization_CINAR.R
            summaries/DFO_biomass_summary.csv  -->  figures/CINAR_all_regions_shallow.png
                                                    figures/CINAR_all_regions_deep.png

[Step 4b] R/DFO_biomass_visualization_EcoMon.R
            summaries/DFO_biomass_summary.csv  -->  figures/Biomass_interannual_36_37.png

[Step 4e] R/DFO_CINAR_polygon_map.R
            polygons/*.csv + data/poly_*.csv   -->  figures/CINAR_polygons_map.png

[Step 4f] R/DFO_EcoMon_strata_map.R
            polygons/*.csv + data/EMstrata_v4_coords.csv
            -->  figures/EcoMon_strata_map.png

[Step 4g] R/DFO_region_map.R
            data/poly_*.csv + data/SBNMS*.csv + data/EMstrata_v4_coords.csv
            -->  figures/DFO_region_map_CINAR.png
                 figures/DFO_region_map_SBNMS.png
```

All active pipeline scripts use `getwd()` for paths (requires opening `SPM_calanus_biomass.Rproj` first).

---

## 2. R Script Reference

### Active Pipeline Scripts

#### `run_pipeline.R` — Master orchestrator
- **Purpose:** Sources all pipeline steps (1 through 4g) in order; documents workflow design, polygon priority, fixed station coordinates, and data sources.
- **Reads:** All R/ pipeline scripts via `source()`
- **Writes:** Nothing directly
- **Status:** Active. Well-documented reference file.

#### `R/DFO_data_process.R` — Step 1
- **Purpose:** Reads raw 3D Calanus biomass RDS files and integrates biomass over three depth layers: shallow (0-80m), deep (>80m), full column.
- **Reads:** `Bioenergy_3D/*.rds` (gitignored; 8.8 GB raw DFO model output)
- **Writes:** `processed/*_processed.csv` (one per input RDS; gitignored)
- **Species:** C. finmarchicus (cfin), C. glacialis (cgla), C. hyperboreus (chyp)
- **Notes:** Uses `tryCatch` to skip files with missing columns. Robust error handling.

#### `R/Data_layer_Polygons.R` — Step 2
- **Purpose:** Assigns each grid point to CINAR regions (8 polygons) and EcoMon survey strata (indices 14-47) via `sf::st_join()` with `st_within` predicate.
- **Reads:** `processed/*_processed.csv`, `data/poly_*.csv` (8 CINAR boundaries), `data/EMstrata_v4_coords.csv`, `cache/ne_strata_cache.rds` (optional)
- **Writes:** `polygons/*_processed_polygons.csv` (adds CINAR_poly and EcoMon_poly columns), `cache/ne_strata_cache.rds`
- **Notes:** Uses `sf_use_s2(FALSE)` for planar geometry. Filters to six DFO regions: CCB, Fundy, GB, GOM, SNE, SS. Deduplicates by Label after spatial join. This is the R port of the original MATLAB `Data_layer_Polygons.m` (removed in cleanup).

#### `R/DFO_data_polygon_summary.R` — Step 3
- **Purpose:** Aggregates point-level biomass to polygon-level statistics (mean, SD, min, max) by year and month.
- **Reads:** `polygons/*_processed_polygons.csv`
- **Writes:** `summaries/DFO_biomass_summary.csv` (single combined file with both CINAR and EcoMon rows)
- **Notes:** Polygon column contains string keys: CINAR names ("WSS", "EGOM", "JB", "Browns", "Halifax", "GeorgesNEC", "GMB150", "BOF") or EcoMon format ("ecomon_14" ... "ecomon_47"). Rows with poly_id == 0 excluded. Inf/-Inf replaced with NA.

#### `R/DFO_biomass_visualization_CINAR.R` — Step 4a
- **Purpose:** Two 8-panel seasonal biomass time-series figures (shallow and deep) for all CINAR regions. C. finmarchicus only.
- **Reads:** `summaries/DFO_biomass_summary.csv` (CINAR rows)
- **Writes:** `figures/CINAR_all_regions_shallow.png`, `figures/CINAR_all_regions_deep.png`
- **Notes:** 4x2 panel grid; viridis plasma color scale by year; error bars = +/- 1 SD.

#### `R/DFO_biomass_visualization_EcoMon.R` — Step 4b
- **Purpose:** 4-panel seasonal biomass figure for EcoMon strata 36 (Western GoM) and 37 (Wilkinson Basin). C. finmarchicus only.
- **Reads:** `summaries/DFO_biomass_summary.csv` (EcoMon rows)
- **Writes:** `figures/Biomass_interannual_36_37.png`
- **Notes:** Only covers 2 of 34 EcoMon strata. No comprehensive EcoMon visualization exists.

#### `R/DFO_CINAR_polygon_map.R` — Step 4e
- **Purpose:** QC map showing SPM grid point assignments to CINAR polygons on bathymetric base.
- **Reads:** `polygons/*_processed_polygons.csv` (first file), `data/poly_*.csv` (8 boundaries), NOAA ETOPO (downloaded)
- **Writes:** `figures/CINAR_polygons_map.png`
- **Notes:** TODO: bathymetry not cached (re-downloads on every run). Map domain -72 to -60W clips WSS, Halifax, and Browns which extend further east.

#### `R/DFO_EcoMon_strata_map.R` — Step 4f
- **Purpose:** Map showing SPM grid point assignments to EcoMon survey strata on cached bathymetry.
- **Reads:** `polygons/*_processed_polygons.csv` (first file), `data/EMstrata_v4_coords.csv`, `cache/gom_bathy_ecomon.rda`
- **Writes:** `figures/EcoMon_strata_map.png`, `cache/gom_bathy_ecomon.rda` (on first run)
- **Notes:** Well-implemented with caching. Shuffled warm palette with seed for reproducibility.

#### `R/DFO_region_map.R` — Step 4g
- **Purpose:** Publication-quality region maps for CINAR and SBNMS/GoM contexts.
- **Reads:** `data/poly_*.csv`, `data/SBNMS.csv`, `data/SBNMS_40m_latlon.csv`, `data/EMstrata_v4_coords.csv`, `mapdata::world2Hires`, `cache/gom_bathy.rda`
- **Writes:** `figures/DFO_region_map_CINAR.png`, `figures/DFO_region_map_SBNMS.png`, `cache/gom_bathy.rda` (on first run)
- **Notes:** Includes fixed station markers (NERACOOS buoys, DFO time series). Land polygons drawn on top for clean masking. Includes a commented-out leaflet interactive map stub.

### Scripts Removed in Cleanup (2026-03-12)

The following scripts were removed during repo cleanup. None were sourced by `run_pipeline.R`.

| Script | Reason for removal |
|--------|--------------------|
| `R/DFO_biomass_visualization.R` | Superseded by `DFO_biomass_visualization_CINAR.R`. Was broken (referenced non-existent legacy summary file). |
| `R/Biomass_interannual_4_plot.R` | Superseded by `DFO_biomass_visualization_CINAR.R`. Was broken (same legacy file issue). |
| `R/DFO_exploration.R` | Scratch/dead code with syntax errors and obsolete column names. |
| `R/Inset_map.R` | Out-of-scope conference presentation art with hardcoded OneDrive paths. |
| `R/PT_interannual_SingleExp.R` | Out-of-scope particle tracking analysis with hardcoded OneDrive paths. |
| `R/PT_track_presentation_map.R` | Out-of-scope particle tracking visualization with hardcoded OneDrive paths. |

---

## 3. MATLAB Script Reference

All MATLAB scripts were removed during repo cleanup (2026-03-12). Their outputs (`data/poly_*.csv` boundary files) are committed as static data. The `matlab/` directory no longer exists.

| Script | Purpose | Reason for removal |
|--------|---------|--------------------|
| `export_for_R.m` | Coordinate conversion and polygon clipping (produced `poly_*.csv`) | Outputs already committed as static data |
| `sp_proj.m` | State plane ↔ geographic projection utility | Only used by `export_for_R.m` |
| `Data_layer_Polygons.m` | Original MATLAB polygon assignment (Step 2) | Superseded by `R/Data_layer_Polygons.R` |
| `CINAR_Setup_figure.m` | Reference map of CINAR polygons | Superseded by R maps in Step 4g |

---

## 4. Data File Reference

### CINAR Polygon Boundaries (`data/poly_*.csv`) — Used by active pipeline

These are the **pre-clipped** polygon boundary files originally produced by `matlab/export_for_R.m` (removed in cleanup) using MATLAB polyshape `subtract()`. They have non-overlapping boundaries following the priority order defined above and are committed as static data. **These are the files read by `R/Data_layer_Polygons.R` (Step 2).**

| File | Polygon | Points | Used by |
|------|---------|--------|---------|
| `poly_GMB_150.csv` | Grand Manan Basin (150m isobath) | 38 | Step 2, Steps 4e/4g |
| `poly_JB_deep.csv` | Jordan Basin | ~20 | Step 2, Steps 4e/4g |
| `poly_GeorgesNEC.csv` | Georges Basin / NE Channel | 26 | Step 2, Steps 4e/4g |
| `poly_BOF_latlon.csv` | Bay of Fundy | 12 | Step 2, Steps 4e/4g |
| `poly_WSS_broad.csv` | Western Scotian Shelf | ~30 | Step 2, Steps 4e/4g |
| `poly_EGOM_broad.csv` | Eastern Gulf of Maine | ~12 | Step 2, Steps 4e/4g |
| `poly_Browns_line.csv` | Browns Bank | ~6 | Step 2, Steps 4e/4g |
| `poly_Halifax_line.csv` | Halifax / Eastern Scotian Shelf | ~6 | Step 2, Steps 4e/4g |
| `poly_GMB_200.csv` | Grand Manan Basin (200m, display-only) | ~12 | Step 4g (outline only) |
| `poly_JB_250.csv` | Jordan Basin (250m, display-only) | ~12 | PT map (display only) |

### Removed Data Files (cleanup 2026-03-12)

The following files were removed as redundant. The original un-clipped polygon coordinate files (`BOF_latlon.csv`, `EGOM_broad.csv`, `WSS_broad.csv`, `GMB_150_latlon.csv`, `GMB_200_latlon.csv`, `JB_deep_latlon.csv`, `JB_250_latlon.csv`, `GeorgesNEC_deep_latlon.csv`, `Browns_line.txt`, `Halifax_line.txt`) were inputs to `export_for_R.m` whose clipped outputs (`poly_*.csv`) are already committed. State plane coordinate files (`GMB_150_sp.csv`, `GMB_200_sp.csv`, `GeorgesNEC_deep_sp.csv`, `JB_250_sp.csv`, `SBNMS_40m_sp.csv`) and the empty `EcoMon_Strata_shp/` directory were also removed.

### SBNMS / Stellwagen Bank Files

| File | Description | Used by |
|------|-------------|---------|
| `SBNMS.csv` | Stellwagen Bank NMS boundary | Step 4g (`DFO_region_map.R`) |
| `SBNMS_40m_latlon.csv` | 40m isobath within SBNMS | Step 4g (`DFO_region_map.R`) |

### EcoMon Strata

| File | Description | Used by |
|------|-------------|---------|
| `EMstrata_v4_coords.csv` | EcoMon stratum boundary coordinates (strata 14-47) | Steps 2, 4f, 4g |

---

## 5. Summary File Reference

| File | Rows | Description | Generated by |
|------|------|-------------|--------------|
| `DFO_biomass_summary.csv` | ~12,793 | **Primary output.** Combined CINAR + EcoMon polygon-level summary (mean, SD, min, max) by fYear/month/polygon. String polygon keys. | Step 3 (`DFO_data_polygon_summary.R`) |

**Note:** Two legacy summary files (`DFO_biomass_CINAR_summary.csv` and `DFO_biomass_EcoMon_summary.csv`) were removed in cleanup (2026-03-12). They were stale artifacts from a prior pipeline version that used separate outputs with numeric polygon IDs.

---

## 6. Figure Reference

| File | Dimensions | Script | Content |
|------|-----------|--------|---------|
| `CINAR_all_regions_shallow.png` | 20x12 in, 300 dpi | Step 4a | 8-panel seasonal C. finmarchicus biomass (0-80m) for all CINAR regions, colored by year |
| `CINAR_all_regions_deep.png` | 20x12 in, 300 dpi | Step 4a | Same as above for deep layer (>80m) |
| `Biomass_interannual_36_37.png` | 10x8 in, 600 dpi | Step 4b | 4-panel seasonal C. finmarchicus for EcoMon strata 36 & 37, shallow + deep |
| `CINAR_polygons_map.png` | 12x10 in, 300 dpi | Step 4e | QC map: grid point polygon assignments on bathymetry |
| `EcoMon_strata_map.png` | 14x10 in, 300 dpi | Step 4f | QC map: grid point EcoMon strata assignments on bathymetry |
| `DFO_region_map_CINAR.png` | 14x9 in, 300 dpi | Step 4g | Publication map: 8 CINAR polygons, stations, transects, bathymetry contours |
| `DFO_region_map_SBNMS.png` | 10x8 in, 300 dpi | Step 4g | Publication map: EcoMon strata 35/36/37/40, SBNMS boundary, stations |

---

## 7. Cache File Reference

| File | Size | Created by | Invalidation |
|------|------|-----------|--------------|
| `cache/gom_bathy.rda` | 2.4 MB | Step 4g (`DFO_region_map.R`) on first run | Delete manually to re-download. Domain: -72 to -60W, 41 to 46N. |
| `cache/gom_bathy_ecomon.rda` | 1.5 MB | Step 4f (`DFO_EcoMon_strata_map.R`) on first run | Delete manually to re-download. Domain: -76 to -63W, 38 to 46N. |
| `cache/ne_strata_cache.rds` | 431 KB | Step 2 (`Data_layer_Polygons.R`) on first run | Delete manually to rebuild from `EMstrata_v4_coords.csv`. sf polygon object for all EcoMon strata. |

---

## 8. Bugs and Inconsistencies

### Broken Scripts (removed in cleanup 2026-03-12)

All previously broken scripts (`R/DFO_biomass_visualization.R`, `R/Biomass_interannual_4_plot.R`, `R/DFO_exploration.R`, `matlab/Data_layer_Polygons.m`) were removed during repo cleanup.

### Issues in Active Pipeline Scripts

| Script | Severity | Issue |
|--------|----------|-------|
| `R/DFO_biomass_visualization_CINAR.R` | Low | Extensive code duplication: 8 regions x 2 depth layers hand-coded instead of using a loop |

### Legacy Data Inconsistency (resolved)

The `summaries/` directory previously contained two legacy files alongside the current output. These were removed in cleanup (2026-03-12). Only `DFO_biomass_summary.csv` remains.

