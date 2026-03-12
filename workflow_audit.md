# Workflow Audit: DFO SDM Calanus Biomass Data Product

**Audited by:** Claude (Sonnet 4.6)
**Date:** March 2026
**Working directory:** `C:\Users\camer\Desktop\SPM_calanus_biomass`
**Workflow document:** `Biomass_data_product_workflow.docx`

---

## Table of Contents

1. [Correct Run Order](#1-correct-run-order)
2. [Reconciliation: Workflow Document vs. Script Behavior](#2-reconciliation-workflow-document-vs-script-behavior)
3. [Scripts Not Described in the Workflow Document](#3-scripts-not-described-in-the-workflow-document)
4. [All Hardcoded File Paths by Script](#4-all-hardcoded-file-paths-by-script)
5. [Incomplete Sections, TODOs, and Workflow Gaps](#5-incomplete-sections-todos-and-workflow-gaps)
6. [Package and Toolbox Requirements](#6-package-and-toolbox-requirements)
7. [Assessment of Map Figure Scripts](#7-assessment-of-map-figure-scripts)
8. [Summary of Highest-Priority Issues](#8-summary-of-highest-priority-issues)

---

## 1. Correct Run Order

```
[Step 1]  DFO_data_process.R              (R)
             reads:  Bioenergy_*_3D.rds  (one per month/year, OneDrive)
             writes: *_processed.csv     (one per input file, OneDrive)

[Step 2]  Data_layer_Polygons.m           (MATLAB — requires sp_proj.m on MATLAB path)
             reads:  *_processed.csv
             writes: *_processed_polygons.csv

[Step 3]  DFO_data_polygon_summary.R      (R)
             reads:  *_processed_polygons.csv
             writes: DFO_biomass_CINAR_summary.csv
             writes: DFO_biomass_EcoMon_summary.csv

[Step 4a] DFO_biomass_visualization_CINAR.R    reads CINAR summary
[Step 4b] DFO_biomass_visualization_EcoMon.R   reads EcoMon summary
[Step 4c] Biomass_interannual_4_plot.R          reads CINAR summary
[Step 4d] DFO_biomass_visualization.R           reads CINAR summary (diagnostic only)
[Step 4e] DFO_CINAR_polygon_map.R               reads polygon CSVs directly

Standalone / presentation figures (no data dependencies on the above):
  CINAR_Setup_figure.m          (MATLAB — static reference map)
  Inset_map.R                   (R — North Atlantic context inset)
  PT_track_presentation_map.R   (R — particle tracking; requires separate MATLAB export)
```

`DFO_exploration.R` is a scratch/exploratory script. It is not part of any run sequence and contains a syntax error. It should not be in the production directory.

---

## 2. Reconciliation: Workflow Document vs. Script Behavior

### Step 4.1 — `DFO_data_process.R`

| Doc says | Script actually does | Verdict |
|---|---|---|
| Filters output to six key regions: CCB, Fundy, GB, GOM, SNE, SS | No region filter at all — outputs all rows from all RDS files | **Discrepancy** |
| Processes April–September only | No month filter — processes whatever RDS files are present in the input directory | **Implicit dependency, not enforced in code** |
| Outputs CSV files with depth-integrated biomass by layer | Correct — one `*_processed.csv` per input RDS file | Match |

**Additional issues not mentioned in the workflow document:**

- `ggplot2` is listed in `library()` calls at the top but is never used anywhere in the script. Dead import.
- The `cfin_C4.6dw.mgm2`, `cgla_C4.6dw.mgm2`, `chyp_C4.6dw.mgm2` columns are carried through via `first()` in the shallow-layer `summarise()`. These appear to be pre-integrated column total values (mg/m²) computed by DFO upstream. If they are constant across all Zlayer rows for a given Label/location (as expected for a site-level attribute on a fixed prediction grid), `first()` is harmless. However, this assumption is nowhere verified. If these columns vary by Zlayer row (e.g., they represent running depth integrals), `first()` picks an arbitrary depth bin and the carried-through values are wrong. This needs verification against DFO's data dictionary.
- The `input_dir` is hardcoded to the OneDrive path, but a `Bioenergy_3D/` subdirectory containing the same RDS files is also present locally at `C:\Users\camer\Desktop\SPM_calanus_biomass\Bioenergy_3D\`. The script will never read the Desktop copies. If the two copies diverge (e.g., after an update from DFO), the script will silently process stale data from whichever copy was not updated.

### Step 4.2 — `Data_layer_Polygons.m`

| Doc says | Script actually does | Verdict |
|---|---|---|
| Loads polygon boundaries for two spatial frameworks: CINAR (8 polygons) and EcoMon survey strata | Correct for both frameworks | Match |
| For each coordinate, determines which polygon it falls within | Correct via `isinterior()` with priority-ordered loop for CINAR; loop over indices 14–47 for EcoMon | Match |
| Appends polygon assignment columns to each record | Adds `CINAR_poly` and `EcoMon_poly` integer columns | Match |
| Doc says filtering to 6 regions happens in Step 4.1 | **Filtering actually happens here** (lines 110–111): `desired_regions = {'CCB', 'Fundy', 'GB', 'GOM', 'SNE', 'SS'}` | **Discrepancy — doc misattributes where filtering occurs** |
| CINAR regions (8 polygons) | Only 8 CINAR shapes are used for assignment; `GMB_200`, `JB_250` are loaded but never assigned | Partial match — auxiliary polygons loaded but silently discarded |

**Critical bugs:**

- **Path mismatch — will cause script failure:** All 14 polygon coordinate files are loaded from `C:/Users/camer/Desktop/vast_local/mydata/` but those files physically exist in `C:\Users\camer\Desktop\SPM_calanus_biomass\`. The script will fail with file-not-found errors unless `vast_local/mydata/` is an independent directory that holds separate copies of these files. This needs to be resolved before the script can run.
- **Unassigned count is reported incorrectly (line 191):** The line `fprintf('  Unassigned: %d points\n', cinar_counts(1))` is wrong. The preceding `histcounts(data_table.CINAR_poly, 0.5:8.5)` call bins values in [0.5, 1.5], [1.5, 2.5], etc. — so `cinar_counts(1)` counts points with `CINAR_poly == 1` (WSS), not unassigned points (`CINAR_poly == 0`). Points with value 0 fall below 0.5 and are entirely outside the histogram bins. The console output labelled "Unassigned" is actually showing the WSS assignment count.

**Other issues:**

- `EMstrata_v4.mat` is loaded with a bare `load('EMstrata_v4.mat')` call with no path. It must be findable on the MATLAB path via `addpath`. The EcoMon stratum indices `j = 14:47` are hardcoded with no documentation of what those index values correspond to in the NES EcoMon stratum numbering system. A change to the MAT file structure would silently produce wrong assignments.
- `sp_proj('1802', 'inverse', ...)` applies a Maine East (FIPS 1802, NAD83) inverse projection to both `GMB_150_sp` and `GeorgesNEC_deep_sp`. Grand Manan Basin is near the Maine/New Brunswick border, so Maine East state plane is plausible. Georges Bank/NE Channel is substantially further south (~41°N, ~67°W). Using Maine East state plane for a Georges Bank polygon needs verification against the source projection of that specific polygon — if it was defined in a different state plane zone, the inverse-projected lat/lons will be spatially displaced.
- `JB_250_sp.csv` and `JB_250_latlon.csv` are both loaded. `JB_250_latlon` is used directly in `CINAR_Setup_figure.m` for display. `JB_250_sp` appears in the `readmatrix()` load list but is never used in any projection or assignment. This loaded-but-unused variable has no explanation.
- The CINAR assignment priority order `[7, 3, 6, 8, 1, 2, 4, 5]` (GMB150 → JB → GeorgesNEC → BOF → WSS → EGOM → Browns → Halifax) resolves overlapping polygon assignments. Browns Bank (4) and Halifax (5) being lowest priority means any point inside an overlapping higher-priority polygon will be assigned there instead of to Browns/Halifax. Whether these polygons actually have spatial overlap and whether this priority order is scientifically correct has no documentation.
- The script uses two sequential full-table row-by-row loops (first for CINAR, then for EcoMon) calling `isinterior()` one row at a time. With ~300 input files each having potentially thousands of rows, this is computationally slow. The vectorized MATLAB function `inpolygon()` or R's `sf::st_contains()` would replace both inner loops and run orders of magnitude faster. This is consistent with the workflow doc TODO to port to R.

### Step 4.3 — `DFO_data_polygon_summary.R`

| Doc says | Script actually does | Verdict |
|---|---|---|
| Filters out sites deeper than 500 m, north of 46°N, and east of 60°W | `filter(bathymetry <= 500) %>% filter(Y <= 46) %>% filter(X <= -60)` | Match |
| Computes mean and SE of biomass by polygon, year, and month | Correct | Match |
| Binds annual/monthly spreadsheets into a single time series per spatial framework | Correct — accumulates into two summary data frames via `bind_rows()` | Match |
| "SE isn't really variance... perhaps a better metric?" | SE as coded is `sd(x)/sqrt(n)` across grid points within a polygon — this is spatial variability across the fixed prediction grid, not sampling uncertainty | **Correctly flagged in doc; metric is implemented as stated but ecological interpretation is problematic** |

**Other issues:**

- The filter `X <= -60` retains all points with longitude more negative than -60°W (i.e., it is an *eastern* domain boundary). The workflow doc describes it as cutting the "western boundary" — the terminology in the doc is reversed.
- The same spatial filter (`bathymetry <= 500`, `Y <= 46`, `X <= -60`) is duplicated independently in `DFO_CINAR_polygon_map.R`. These are two copies of the same logic with no shared function. If the filter thresholds are changed in one script, the other will silently diverge.
- No total water column integrated biomass column is computed here (consistent with the unresolved TODO from Step 4.1, but the issue must be addressed upstream in `DFO_data_process.R` first).

### Step 4.4 — `DFO_biomass_visualization_CINAR.R`

| Doc says | Script actually does | Verdict |
|---|---|---|
| Generates seasonal plots showing biomass patterns across years | Produces 8-panel shallow and 8-panel deep layer figures for all CINAR regions | Match |
| Error bars represent SE across sites within each polygon | Correct — uses `mean ± se_cfin` columns | Match |
| Implicitly: covers the full dataset | Only plots *C. finmarchicus* (cfin); *C. glacialis* and *C. hyperboreus* are absent from all figures | **Omission not flagged in doc** |

**Other issues:**

- The entire script consists of 16 individually coded plot objects (8 regions × 2 depth layers) with no loop or function. This is approximately 320 lines that could be replaced by a ~20-line loop calling a `make_plot()` function identical in structure to the one already written in `Biomass_interannual_4_plot.R`.
- `scale_x_continuous(breaks = 1:12, labels = c("J","F","M","A","M","J","J","A","S","O","N","D"))` defines axis ticks for all 12 months, but the current dataset only covers April–September (months 4–9). Tick marks for Jan/Feb/Mar/Oct/Nov/Dec will be drawn with no data. This is visually misleading.
- `get_legend()` is defined as a local function — the same function body is independently repeated in `DFO_biomass_visualization_EcoMon.R` and `Biomass_interannual_4_plot.R`. Three identical function definitions with no shared source.
- `geom_line(size = 0.8)` — the `size` aesthetic is deprecated for line geoms in ggplot2 ≥ 3.4.0 in favor of `linewidth`. Will generate deprecation warnings on current ggplot2 versions.
- A `summary_table` data frame is constructed at the end of the script but is never printed, returned, or saved. Dead code.

---

## 3. Scripts Not Described in the Workflow Document

The following scripts are present in the working directory and appear in the doc's appendix file listing, but are not described as workflow steps:

### `DFO_biomass_visualization_EcoMon.R`

- **Reads:** `DFO_biomass_EcoMon_summary.csv`
- **Writes:** `Biomass_interannual_36_37.png` → `CINAR_results/PT_ouput_figures/` (note: "ouput" is a persistent typo in this directory name, appearing consistently across multiple scripts)
- **Packages:** dplyr, ggplot2, viridis, scales, gridExtra, grid
- **Function:** Plots *C. finmarchicus* biomass for EcoMon strata 36 and 37 only (two specific strata, two depth layers = 4 panels). Presentation figure, not a comprehensive EcoMon visualization.
- **Issues:**
  - `legend_breaks <- unique(c(all_years[seq(1, length(all_years), by = 4)], 2023))` hardcodes 2023 as the final year to include in legend breaks. With data now extending through 2024, year 2024 will be omitted from the year legend labels.
  - Only plots *C. finmarchicus*. No mention of this scope in comments.
  - `make_plot()` uses `labs(x = "")` (empty string) rather than `"Month"` as in other scripts.
  - There is no equivalent comprehensive visualization for all EcoMon strata. This script covers only 2 of the 34 EcoMon strata present in the data.

### `DFO_biomass_visualization.R`

- **Reads:** `DFO_biomass_CINAR_summary.csv`
- **Writes:** `GMB150_Cfin_shallow_seasonal.png`, `GMB150_Cfin_deep_seasonal.png`, `GMB150_Cfin_combined_seasonal.png` — **saved to R's working directory at runtime with no `setwd()` or explicit output path**. Destination is unpredictable.
- **Packages:** dplyr, ggplot2, viridis, scales, gridExtra (loaded mid-script at line 105, not at the header)
- **Function:** Diagnostic/prototype — single region (GMB150), single species (cfin), with summary statistics printed to console including peak biomass months.
- **Issues:**
  - Subtitle hardcodes "1999-2023" despite data now covering 1999-2024.
  - `library(gridExtra)` appears inside the script body at line 105 rather than in the header with other library calls.
  - `ggsave()` calls contain no output directory path — files will be written to R's working directory at the time of execution.
  - This is a prototype/exploratory script for a single region, not a general-purpose visualization tool.

### `Biomass_interannual_4_plot.R`

- **Reads:** `DFO_biomass_CINAR_summary.csv`
- **Writes:** `Biomass_interannual.png` → `CINAR_results/PT_ouput_figures/`
- **Packages:** dplyr, ggplot2, viridis, scales, gridExtra, grid
- **Function:** 4-panel interannual comparison for WSS (CINAR_poly 1) and Jordan Basin (CINAR_poly 3), shallow and deep layers.
- **Issues:**
  - Only two of the eight CINAR regions are shown; hardcoded to polygons 1 and 3.
  - Same `legend_breaks` hardcoded-2023 issue as `DFO_biomass_visualization_EcoMon.R`.
  - Only plots *C. finmarchicus*.
  - `make_plot()` function is a verbatim duplicate of the one in `DFO_biomass_visualization_EcoMon.R`. Two identical function definitions with no shared source.

### `DFO_CINAR_polygon_map.R`

- **Reads:** First available `*_polygons.csv` from the polygons directory (`available_files[1]` — which year/month is selected is arbitrary). Downloads NOAA ETOPO bathymetry at 0.5 arc-min resolution via `marmap::getNOAA.bathy()` (requires internet connection; no local caching implemented here unlike `PT_track_presentation_map.R`).
- **Writes:** `CINAR_polygons_map.png` → summaries directory
- **Packages:** marmap, dplyr, RColorBrewer
- **Function:** Spatial QC/verification map showing which SDM model grid points fall in which CINAR polygon assignment, on a marmap bathymetric base.
- **Issues:**
  - Map domain `xlim = c(-72, -60), ylim = c(41, 46)` clips the Western Scotian Shelf, Halifax, and Browns Bank polygons, which extend east of -60°W (Halifax to approximately -57°W). The spatial coverage shown is incomplete.
  - `cinar_colors <- c(brewer.pal(8, "RdYlGn"))` followed by `names(cinar_colors) <- c("1", "5", "3", "2", "8", "6", "7", "4")` assigns colors via a non-sequential index with no explanation of why this specific color-to-region mapping was chosen.
  - Uses base R `plot.bathy()` + `points()` rather than ggplot2 — inconsistent with every other R script in the workflow.
  - Applies the same spatial filter (`bathymetry <= 500`, `Y <= 46`, `X <= -60`) that also appears in `DFO_data_polygon_summary.R`. Second independent copy of the same logic.

### `DFO_exploration.R`

- **Reads:** Three hardcoded RDS file paths from different test/staging OneDrive locations. Also references the `akima` package for spatial interpolation.
- **Writes:** Nothing — interactive/exploratory only.
- **This script is not part of the workflow and should not be in the production directory.**
- **Issues:**
  - Line 69: bare `head` with no arguments — this is an incomplete expression and a syntax error. The script cannot be `source()`d without error.
  - Uses old column naming convention (`sum_cfin_100`, `sum_cfin_Diapause`) that was superseded by `sum_cfin_0_80` / `sum_cfin_below_80` in the current `DFO_data_process.R`. These names reflect an earlier draft of the depth-layer integration logic.
  - The biomass normalization at line 77 (`sum_cfin_100 / bathymetry`) divides total column-integrated biomass (mg/m²) by bathymetry (m) to produce mg/m³. This is not a standard oceanographic calculation and is not explained. Dividing depth-integrated mg/m² by total water column depth assumes uniform vertical distribution, which contradicts the purpose of computing separate shallow/deep layers.
  - Log10 color scale applied without handling zeros or negative values — will silently produce NAs or warnings.
  - Three different hardcoded paths to the same or similar RDS file indicate this was written during initial data exploration when files existed in multiple test locations simultaneously.

---

## 4. All Hardcoded File Paths by Script

### `DFO_data_process.R`
```
input_dir:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass
output_dir: C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_processed
```

### `Data_layer_Polygons.m`
```
addpath:    C:/Users/camer/Desktop/vast_local/mytoolbox
addpath:    C:/Users/camer/Desktop/vast_local/mydata
input_dir:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_processed
output_dir: C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_polygons

Polygon coordinate files (all from vast_local/mydata/ — see path mismatch note):
  Browns_line.txt
  Halifax_line.txt
  JB_deep_latlon.csv
  GeorgesNEC_deep_latlon.csv
  GeorgesNEC_deep_sp.csv
  GMB_200_latlon.csv
  GMB_200_sp.csv
  GMB_150_latlon.csv
  GMB_150_sp.csv
  BOF_latlon.csv
  WSS_broad.csv
  EGOM_broad.csv
  JB_250_sp.csv
  JB_250_latlon.csv

EMstrata_v4.mat  — bare load(), no path; must be on MATLAB path
```
> **Note:** These polygon files physically exist in `C:\Users\camer\Desktop\SPM_calanus_biomass\`, not in `vast_local/mydata/`. This is a critical path mismatch that will cause the script to fail.

### `DFO_data_polygon_summary.R`
```
input_dir:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_polygons
output_dir: C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries
```

### `DFO_biomass_visualization_CINAR.R`
```
input:      C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries/DFO_biomass_CINAR_summary.csv
output_dir: C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries
```

### `DFO_biomass_visualization_EcoMon.R`
```
input:   C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries/DFO_biomass_EcoMon_summary.csv
setwd:   C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures  [TYPO: "ouput"]
output:  [setwd path]/Biomass_interannual_36_37.png
```

### `DFO_biomass_visualization.R`
```
input:   C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries/DFO_biomass_CINAR_summary.csv
output:  [no path set — R working directory at runtime; destination is unpredictable]
```

### `Biomass_interannual_4_plot.R`
```
input:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries/DFO_biomass_CINAR_summary.csv
setwd:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures  [TYPO: "ouput"]
output: [setwd path]/Biomass_interannual.png
```

### `DFO_CINAR_polygon_map.R`
```
polygon_dir: C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_polygons
output_dir:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass_summaries
Bathymetry:  downloaded via getNOAA.bathy() — no local path; requires internet; no caching
```

### `Inset_map.R`
```
setwd:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures  [TYPO: "ouput"]
output: [setwd path]/inset_map.png
```

### `PT_track_presentation_map.R`
```
workdir:       C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR
particle data: [workdir]/Lon_[run_date_str].csv, Lat_[run_date_str].csv
polygon data:  [workdir]/poly_[name].csv  (must be pre-exported from MATLAB; files not present)
bathy cache:   [workdir]/gom_bathy.rda
output setwd:  C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/CINAR_results/PT_ouput_figures
run_date_str:  "20140505"  [hardcoded date; must change per run]
```

### `CINAR_Setup_figure.m`
```
addpath:    C:/Users/camer/Desktop/vast_local/mytoolbox
addpath:    C:/Users/camer/Desktop/vast_local/mydata
Data files: C:/Users/camer/Desktop/vast_local/mydata/[each polygon file]  (same path mismatch as Data_layer_Polygons.m)
GOM3_coast.mat — bare load(), no path; must be on MATLAB path
output: C:\Users\camer\OneDrive - Woods Hole Oceanographic Institution\CINAR_results\PT_ouput_figures\regions_map.png
```

### `DFO_exploration.R`
```
C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_test/Bioenergy_1999_04_3D.rds
C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/Data/DFO_calanus_biomass/Bioenergy_1999_04_3D.rds
C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR/Bioenergy_1999_04_3D.rds
C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR/Bioenergy_1999_04.rds
```

---

## 5. Incomplete Sections, TODOs, and Workflow Gaps

### Explicitly flagged in the workflow document

1. **Step 4.1 — All months not yet processed:** The comment "need to update so all months processed" indicates intent to extend beyond April–September. Currently there is no month filter in the code; the scope is entirely determined by which RDS files DFO provides. Adding a month filter would be needed once full-year data is available.

2. **Step 4.1 — Missing total water column integration:** "need another column of total (full water column) integrated biomass" — neither `DFO_data_process.R` nor any downstream script computes or carries a sum of `DW_Zlayer_mg_*` across all depth layers at each grid point. This would require adding a third `group_by` / `summarise` block (no filter on Zlayer) in `process_calanus_data()` before the shallow/deep merge.

3. **Step 4.1 — Region verification:** "need to check/verify regions" — the `REGION` column values used in `Data_layer_Polygons.m` for filtering (`CCB`, `Fundy`, `GB`, `GOM`, `SNE`, `SS`) have not been formally validated against all unique `REGION` values present in the source RDS files. `DFO_exploration.R` contains `unique(Bioenergy_1999_04_3D$REGION)` which was presumably run for this purpose, but the result is not recorded anywhere in the workflow documentation.

4. **Step 4.2 — Port to R:** "be better to port this to R" — vectorized point-in-polygon operations using `sf::st_contains()` or `sp::over()` would replace both slow row-by-row MATLAB loops and eliminate the MATLAB dependency for the processing pipeline entirely.

5. **Step 4.2 — File dependencies not tracked:** "need to identify the file dependencies that should be organized locally and put on git" — the following files are critical workflow dependencies currently not tracked in the repository or documented with canonical locations:
   - `sp_proj.m` (custom MATLAB function, currently in `vast_local/mytoolbox`)
   - `EMstrata_v4.mat` (EcoMon strata polygons; location not documented)
   - `GOM3_coast.mat` (Gulf of Maine coastline; location not documented)
   - All polygon coordinate files (`Browns_line.txt`, `Halifax_line.txt`, the 12 CSV files)

6. **Step 4.3 — SE metric:** The document explicitly notes the SE across polygon grid points is spatial variability, not temporal or sampling uncertainty, and questions whether it is the right metric. No alternative has been implemented. Standard deviation of the concentration (`DW_Zlayer_mg_*` before integration) has been suggested as a more informative measure of within-polygon spatial spread.

7. **Step 5 — Archiving:** "To be documented" — this section is entirely blank. No archiving, versioning, or long-term storage protocol has been described.

### Gaps not flagged in the document

8. ***C. glacialis* and *C. hyperboreus* are never visualized.** All four visualization scripts plot only `cfin` (*C. finmarchicus*). The CINAR and EcoMon summary CSVs contain processed biomass columns for all three species (`mean_cfin_*`, `mean_cgla_*`, `mean_chyp_*`, `se_cfin_*`, `se_cgla_*`, `se_chyp_*`) but none of the downstream scripts use the cgla or chyp columns. Two of the three species in the data product are invisible in all outputs.

9. **No comprehensive EcoMon visualization exists.** `DFO_biomass_visualization_EcoMon.R` plots only strata 36 and 37. There is no script equivalent to `DFO_biomass_visualization_CINAR.R` that covers all 34 EcoMon strata represented in `DFO_biomass_EcoMon_summary.csv`.

10. **`DFO_exploration.R` has a syntax error.** The bare `head` at line 69 is an incomplete expression. This file cannot be `source()`d without error. It also references column names from a prior version of the processing code. It should be removed from the directory.

11. **`PT_track_presentation_map.R` requires a missing MATLAB script.** The file header states "Run `export_for_R.m` in MATLAB from the particle tracking directory" as a prerequisite. `export_for_R.m` is not present in this directory. The polygon CSV files it would produce (`poly_EGOM_broad.csv`, `poly_WSS_broad.csv`, etc.) are also absent. This script cannot be run from the current directory state.

12. **`DFO_biomass_visualization.R` has no output path.** The three `ggsave()` calls contain only filenames with no directory path. Output files will be written to R's current working directory at the time of execution, which varies by R session.

13. **Duplicate data copies may diverge.** `Bioenergy_3D/` on the Desktop and the `DFO_calanus_biomass/` directory on OneDrive appear to contain the same source RDS files. `DFO_data_process.R` reads exclusively from OneDrive. If DFO provides an updated dataset and only one copy is updated, the script will silently process the wrong version.

14. **The `PT_ouput_figures` directory name has a consistent typo** ("ouput" instead of "output") across `DFO_biomass_visualization_EcoMon.R`, `Biomass_interannual_4_plot.R`, `Inset_map.R`, `PT_track_presentation_map.R`, and `CINAR_Setup_figure.m`. All five scripts write to this misspelled path. Correcting the typo in any one script will cause it to write to a different directory than the others.

---

## 6. Package and Toolbox Requirements

| Script | Language | Packages / Toolboxes Required |
|---|---|---|
| `DFO_data_process.R` | R | dplyr, tidyr *(ggplot2 loaded but unused)* |
| `Data_layer_Polygons.m` | MATLAB | Standard MATLAB; Mapping Toolbox (polyshape, isinterior — requires R2017b+); custom `sp_proj.m`; `EMstrata_v4.mat` on path |
| `DFO_data_polygon_summary.R` | R | dplyr, tidyr |
| `DFO_biomass_visualization_CINAR.R` | R | dplyr, ggplot2, viridis, scales, gridExtra, grid |
| `DFO_biomass_visualization_EcoMon.R` | R | dplyr, ggplot2, viridis, scales, gridExtra, grid |
| `DFO_biomass_visualization.R` | R | dplyr, ggplot2, viridis, scales, gridExtra *(loaded mid-script)* |
| `Biomass_interannual_4_plot.R` | R | dplyr, ggplot2, viridis, scales, gridExtra, grid |
| `DFO_CINAR_polygon_map.R` | R | marmap, dplyr, RColorBrewer; internet access for NOAA bathymetry download |
| `Inset_map.R` | R | ggplot2, maps |
| `PT_track_presentation_map.R` | R | marmap, ggplot2, mapdata |
| `CINAR_Setup_figure.m` | MATLAB | Standard MATLAB; `GOM3_coast.mat` on path; custom mytoolbox on path |
| `DFO_exploration.R` | R | dplyr, tidyr, ggplot2, viridis, akima *(scratch — not production)* |

---

## 7. Assessment of Map Figure Scripts

There are four scripts that produce map-type figures (`CINAR_Setup_figure.m`, `DFO_CINAR_polygon_map.R`, `Inset_map.R`, `PT_track_presentation_map.R`). They serve distinct purposes, are inconsistent with each other, and only two are directly related to the biomass data workflow.

### `CINAR_Setup_figure.m`
The canonical reference map for the CINAR polygon framework. Shows all 8 analysis polygons, the auxiliary GMB-200 isobath and JB-250 contour, and four CINAR mooring/station positions (Prince 5, JB Buoy M, NEC Buoy N, Halifax H2). This is the figure that explains the spatial design of the analysis. It is a standalone MATLAB figure using `GOM3_coast.mat` for the coastline and has no direct R equivalent. It shares the same `vast_local/mydata/` path dependency as `Data_layer_Polygons.m`.

### `DFO_CINAR_polygon_map.R`
A data-diagnostic map showing which SDM model grid points fall in which CINAR polygon assignment, on a marmap bathymetric base. Useful for QC but has a restricted domain (`-72 to -60°W`, `41–46°N`) that clips the Western Scotian Shelf, Halifax, and Browns Bank polygons. Uses base-R graphics (`plot.bathy()` + `points()`) while all other R scripts in the workflow use ggplot2. The polygon color palette (`RdYlGn` with non-sequential assignment) is defined independently from both `CINAR_Setup_figure.m` and `PT_track_presentation_map.R` — all three scripts use different, uncoordinated color mappings for the same regions.

### `Inset_map.R`
A North Atlantic context figure for a presentation. Contains an OSM 2026 Glasgow conference marker. Has no direct relationship to the biomass processing workflow and is presentation-specific context art. It pairs with `PT_track_presentation_map.R` (the bounding box in the inset matches the main map domain exactly).

### `PT_track_presentation_map.R`
A particle tracking visualization for CINAR that uses the CINAR polygon boundaries as spatial context but does not depict biomass. It requires pre-exported polygon CSV boundaries from a MATLAB script (`export_for_R.m`) that is not present in this directory. The polygon CSV files it needs are also not present. The color definitions (`region_pal`) are defined independently from the other two map scripts. The script also saves two different PNG files from the same plot object with different filenames and dimensions (one `GMB15_*.png`, one `PT_*.png`).

### Consolidation recommendation

These four scripts serve three distinct purposes that should not be merged:

1. **Polygon reference map** (explaining what the regions are) — currently `CINAR_Setup_figure.m`. An R port using ggplot2 and the polygon coordinate CSV files already in this directory would eliminate the MATLAB dependency for figures and allow a consistent base map style. `GOM3_coast.mat` would need to be replaced with a standard R coastline source (e.g., `rnaturalearth` or `mapdata`).

2. **Data coverage / QC map** (showing which model grid points received polygon assignments) — currently `DFO_CINAR_polygon_map.R`. This should be ported to ggplot2 for consistency, and its domain extended to cover the full extent of all 8 CINAR polygons (approximately `-72 to -55°W`, `41–47°N`).

3. **Particle tracking map** (unrelated to biomass workflow) — `PT_track_presentation_map.R` and `Inset_map.R`. These belong in a separate particle-tracking analysis directory and do not belong in the biomass workflow directory. Keeping them here creates confusion about scope and adds undocumented dependencies (`export_for_R.m`) that can never be satisfied from within this directory.

**Key structural issue across all map scripts:** There is no shared color palette definition for the CINAR regions. Each script that assigns colors to polygons (`CINAR_Setup_figure.m`, `DFO_CINAR_polygon_map.R`, `PT_track_presentation_map.R`) defines its own independent named color vector with no coordination. A single authoritative color definition — either as a sourced R script or a MATLAB struct — should be established and referenced by all figure scripts to ensure consistent region-to-color mapping across publications and presentations.

---

## 8. Summary of Highest-Priority Issues

| # | Severity | Script | Issue |
|---|---|---|---|
| 1 | **Will cause failure** | `Data_layer_Polygons.m` | Polygon data files loaded from `vast_local/mydata/` but physically located in `SPM_calanus_biomass/`. Script will error on file-not-found unless `vast_local/mydata/` independently contains copies. |
| 2 | **Silent wrong output** | `Data_layer_Polygons.m` | "Unassigned" count in console output (line 191) reports WSS assignment count (`CINAR_poly == 1`), not actual unassigned count (`CINAR_poly == 0`). |
| 3 | **Potentially wrong spatial output** | `Data_layer_Polygons.m` | `sp_proj('1802', 'inverse', ...)` (Maine East state plane, NAD83) applied to `GeorgesNEC_deep_sp.csv`. Georges Bank / NE Channel is well outside the Maine East zone. Needs verification against the source projection of that polygon file. |
| 4 | **Data version risk** | `DFO_data_process.R` vs. directory | Local `Bioenergy_3D/` copy on Desktop never read by any script; `input_dir` reads from OneDrive. Two copies may diverge after dataset updates. |
| 5 | **Missing scientific output** | All steps | Total water column integrated biomass (sum across all Zlayers) never computed despite explicit TODO. No full-column index exists anywhere in the pipeline. |
| 6 | **Missing scientific output** | All visualization scripts | *C. glacialis* and *C. hyperboreus* never visualized. Two of three species in the data product produce no figures. |
| 7 | **Stale hardcode** | `DFO_biomass_visualization_EcoMon.R`, `Biomass_interannual_4_plot.R` | `legend_breaks` hardcodes 2023 as the final labeled year. Year 2024 data will be present but unlabeled in all legends. |
| 8 | **Doc / code mismatch** | `DFO_data_process.R` vs. doc | Workflow doc says Step 4.1 filters to 6 regions (CCB, Fundy, GB, GOM, SNE, SS). Filtering actually occurs in Step 4.2 (MATLAB). |
| 9 | **Script with syntax error in production directory** | `DFO_exploration.R` | Bare `head` at line 69 is a syntax error; old column names from a prior code version; three paths to test data. This script should be removed from the directory. |
| 10 | **Broken / incomplete script** | `PT_track_presentation_map.R` | Requires `export_for_R.m` (absent from directory) and `poly_*.csv` files (absent). Cannot be run in its current state. Belongs in a separate particle-tracking directory. |
| 11 | **Missing feature** | `DFO_CINAR_polygon_map.R` | Map domain clips WSS, Halifax, Browns Bank polygons. Not representative of full analysis spatial extent. |
| 12 | **Consistent typo in output path** | `DFO_biomass_visualization_EcoMon.R`, `Biomass_interannual_4_plot.R`, `Inset_map.R`, `PT_track_presentation_map.R`, `CINAR_Setup_figure.m` | All five write to `PT_ouput_figures` ("ouput" not "output"). Correcting in any one script will cause output path divergence from the others. |
| 13 | **Undocumented file dependencies** | `Data_layer_Polygons.m`, `CINAR_Setup_figure.m` | `EMstrata_v4.mat`, `GOM3_coast.mat`, and `sp_proj.m` are critical dependencies with no documented canonical location and no version tracking. |
| 14 | **No EcoMon-wide visualization** | `DFO_biomass_visualization_EcoMon.R` | Only strata 36 and 37 plotted. No script covers all EcoMon strata equivalent to the CINAR 8-panel figure. |
