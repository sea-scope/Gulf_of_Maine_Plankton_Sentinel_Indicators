# Gulf of Maine Plankton Sentinel Indicators — Work Packages

**Repository:** `sea-scope/Gulf_of_Maine_Plankton_Sentinel_Indicators`  
**Local path:** `C:\Users\camer\Desktop\SPM_calanus_biomass`  
**Primary author:** Cameron Thompson, NERACOOS  
**Prepared:** March 12, 2026 (living document)

---

## Overview

This document organizes the remaining development work for the Gulf of Maine Plankton Sentinel Indicators project into discrete work packages. The primary near-term deliverable is a GitHub Pages interactive site, beginning with the SPM biomass viewer and expanding to incorporate time series station indicators, satellite-derived products, and connectivity metrics.

Work packages are organized into four phases:

| Phase | Focus | Key Deliverables | Work Packages |
|-------|-------|-------------------|---------------|
| 1 | SPM Biomass Pipeline + First Interactive Viewer | Per-polygon/stratum figures, interactive site, GitHub Pages deployment | WP1, WP2, WP3 |
| 2 | Time Series Station Integration | WBTS/CMTS scripts in repo, station-level figures, second interactive viewer | WP4, WP5 |
| 3 | Satellite SST/Chl Products | Polygon extraction pipeline, satellite figures on site | WP6 |
| 4 | Full Website + Automation | Quarto site, narrative pages, automated update workflow | WP7, WP8 |

The project will produce **two separate interactive viewers**: one for SPM biomass at polygons/strata (Phase 1) and one for time series station data (Phase 2). This separation simplifies development and allows each to be built independently.

---

## Phase 1: SPM Biomass Pipeline Completion and Interactive Viewer

Phase 1 extends the cleaned SPM biomass pipeline to produce the per-polygon and per-year figures needed for the interactive site, then builds and deploys the viewer on GitHub Pages. This is the critical path to the primary deliverable.

### WP1: SPM Biomass Figure Generation

**Objective:** Extend the visualization scripts to produce the full set of individual figures needed for the interactive viewer, including per-polygon/stratum plots for all years combined and for each individual year with climatological context.

**Tasks:**

1. Refactor `DFO_biomass_visualization_CINAR.R` to loop over all 8 CINAR polygons and all 34 EcoMon strata, saving individual PNG files per polygon/stratum. This eliminates the hand-coded 8-region x 2-depth duplication flagged in the audit as the only active bug.

2. Create a new visualization mode: **single-year figures** where the selected year is drawn as a solid line over two shaded envelopes:
   - Outer envelope (lighter shade): range of mean +/- SD of biomass across all years
   - Inner envelope (darker shade): range of annual mean values across years
   - These single-year figures are the primary content for the interactive viewer.

3. **Bathymetry annotations on every figure.** Calculate mean and SD bathymetry for each polygon/stratum from the existing bathymetry column in the polygon-processed datasets. Display as text annotation on each individual figure (e.g., "Mean depth: 187 +/- 42 m"). Update `DFO_data_polygon_summary.R` (Step 3) to compute and include bathymetry summary statistics in the output summary CSV.

4. Add **SBNMS and Stellwagen Bank** as additional polygons in the pipeline: define polygon boundary CSVs, add to Step 2 polygon assignment, carry through Steps 3 and 4.

5. Establish consistent figure naming convention:
   - `figures/spm_biomass/{polygon_id}_{year}_shallow.png` for single-year plots
   - `figures/spm_biomass/{polygon_id}_{year}_deep.png`
   - `figures/spm_biomass/{polygon_id}_all_years_shallow.png` for combined plots
   - `figures/spm_biomass/{polygon_id}_all_years_deep.png`

6. **Authorship update (repo-wide).** Update file headers, script comments, and any README/documentation across the entire repository: primary author Cameron Thompson, with aid of Claude AI (Anthropic). Cameron is currently the sole contributor. This is a repo-wide find-and-replace task, not per-script.

7. **Data update workflow.** Document the procedure for incorporating a new annual DFO data release, referencing the dataset readme (attached). Key steps: obtain updated zip from DFO FTP or contacts (Caroline Lehoux, Eve Rioux), extract on Poseidon, rsync Bioenergy_3D/ to local machine, rerun Steps 1-4. Note that FTP links expire and the 2024 update reduced spatial extent (Northumberland Strait, upper Bay of Fundy removed). Include the DFO contact information and the nohup/wget/unzip command from the dataset readme.

**Dependencies:** Completed repo cleanup and audit (done). Pipeline runs end-to-end through Steps 1-4g.

**Outputs:** ~300+ individual PNG figures in `figures/spm_biomass/` with systematic naming. Updated `DFO_biomass_summary.csv` with bathymetry stats. SBNMS/Stellwagen polygons integrated. Repo-wide authorship headers. Data update documentation.

**Notes:** The code duplication in the CINAR visualization script is the only active bug from the audit. Refactoring to a loop is the natural first task. The single-year-with-envelope figure design is new development but straightforward with the existing ggplot2 structure. After WP1 is complete, a follow-up audit should be run to verify the pipeline state.

---

### WP2: Interactive Viewer — SPM Biomass (Polygons/Strata)

**Objective:** Build a static, client-side interactive visualization for the SPM biomass data product, hosted on GitHub Pages, allowing users to explore biomass by polygon/stratum, year, depth layer, and species.

**Design decision — map interaction approach:**

There are two viable approaches for polygon/stratum selection:

- **Option A: Dropdown menus.** Three dropdowns: polygon/stratum, year, depth layer. Static reference map displayed alongside. Simplest to build, easiest to maintain, no spatial library dependency.

- **Option B: Clickable Leaflet map.** Polygons and strata rendered as clickable regions on an interactive map. Year slider and depth toggle as additional controls. More engaging but requires Leaflet, GeoJSON conversion of polygon boundaries, and more JavaScript.

**Recommendation: Start with Option A (dropdowns + static map).** The primary value of the viewer is access to the figures, not the map interaction itself. Dropdowns are faster to build, easier to debug, and more robust on GitHub Pages. A Leaflet version can be added later as a refinement. The static map should clearly show all polygons/strata with labels so users can orient themselves.

**Tasks:**

1. Build the viewer as `index.html` + `style.css` + `script.js`. Three dropdown menus:
   - Polygon/stratum (all CINAR polygons + all EcoMon strata + SBNMS/Stellwagen)
   - Year (1999-2024, plus "All Years" option)
   - Depth layer (Shallow 0-80m / Deep >80m)

2. Include a static reference map (PNG, generated in R from the existing `DFO_region_map.R` or similar) showing all polygon/stratum boundaries with labels. This map is always visible.

3. Wire dropdown changes to dynamically swap the displayed figure by constructing the image path from the WP1 naming convention: `figures/spm_biomass/{polygon_id}_{year}_{depth}.png`.

4. Create a `metadata.json` file listing all available polygon/stratum IDs, display names, and available years. The viewer reads this to populate dropdown options.

5. Add a placeholder/hook for future data types (satellite SST, Chl) so the viewer can be extended in WP6 without restructuring.

6. **This viewer is for SPM biomass at polygons/strata only.** Time series station data will have a separate viewer (WP5). This separation keeps each viewer simple and allows independent development.

7. Test with a small subset of figures before running the full WP1 figure generation.

**Dependencies:** WP1 (naming convention must be established; a handful of test figures suffice for initial development). WP1 and WP2 can proceed in parallel.

**Outputs:** Working interactive viewer (`index.html`, `script.js`, `style.css`, `metadata.json`, static reference map) that loads pre-generated figures from `figures/spm_biomass/`.

---

### WP3: GitHub Pages Deployment (Initial/Temporary)

**Objective:** Deploy the interactive viewer on GitHub Pages. This may be a temporary deployment that is later replaced by a Quarto site (WP7) or ported to NERACOOS.org, so keep the infrastructure minimal.

**Tasks:**

1. Organize site files into a `docs/` directory (or configure GitHub Pages to serve from a branch/folder). Keep the structure simple since this may be replaced.

2. Figure hosting strategy: the full figure set (~300 PNGs at ~0.2 MB each = ~60 MB) fits within GitHub repo size guidelines. Commit directly for now. If the figure count grows substantially (adding satellite, time series), revisit with GitHub LFS or external hosting.

3. Configure GitHub Pages in repository settings. Verify the viewer loads and figures swap correctly on the public URL.

4. Write a brief README section documenting the site structure and how to update figures.

5. Do not invest in custom domains, analytics, or elaborate navigation at this stage. The Quarto site (WP7) will provide the proper wrapper.

**Dependencies:** WP2 (working viewer). WP1 (at least a representative subset of figures).

**Outputs:** Live site at `https://sea-scope.github.io/Gulf_of_Maine_Plankton_Sentinel_Indicators/` displaying the SPM biomass interactive viewer.

**Notes:** This is explicitly a temporary step. Keep effort proportional. The goal is to get figures accessible on the web quickly, not to build a polished site. The Quarto build (WP7) or a NERACOOS.org port will be the long-term home.

---

## Phase 2: Time Series Station Integration

Phase 2 collects the scattered WBTS and CMTS GAM analysis scripts into the repository, documents the data preparation pipeline, and produces a second interactive viewer for station-level indicators.

### WP4: WBTS/CMTS Script Consolidation and Data Pipeline Documentation

**Objective:** Gather the existing R scripts for all time series station variables into the repository with a consistent structure, and document the current data preparation workflow from sample collection to analysis-ready data.

**Variables:**
- Calanus abundance index (C3-C6)
- Copepodite stage index (CSI, C1-C6)
- Total mesozooplankton biomass (dry weight g m-2)
- Integrated chlorophyll-a (0-50 m)
- Upper water column temperature
- Lower water column temperature

**Stations:** WBTS, CMTS, MWRA sites (for Calanus abundance index)

**Tasks:**

1. Inventory all existing scripts across desktop locations. For each, document: current file path, input data sources (file names, formats), output figures/data, and whether the script currently runs end-to-end.

2. Create a new directory structure within the repo: `R/timeseries/` for scripts, `data/timeseries/` for input data files, `figures/timeseries/` for outputs.

3. Port each script into the repo, updating paths to use relative references (`getwd()` via `.Rproj`). Preserve the existing GAM specifications and seasonal definitions exactly as published in Runge et al. (2025):
   - Winter: January 1 to March 15
   - Spring: March 16 to May 27
   - Summer: May 28 to September 4
   - Fall: September 5 to December 31
   - GAM: cyclic cubic spline for DOY, spline for year, autoregressive term

4. For each variable, ensure the script produces both the climatology figure (annual cycle) and the seasonal trend figure (interannual by season).

5. Add CMTS station scripts alongside WBTS. Document any differences in methods, coverage gaps, or variable availability between the two stations. Include MWRA station scripts for Calanus abundance index if available.

6. **Document the current data preparation pipeline.** This is currently a manual process: sample enumeration from paper notes to Excel spreadsheets. Document the steps as-is, including: who does the enumeration, what the paper forms look like, how data enters Excel, what QA/QC is applied, and where the analysis-ready files live. This documentation is for reference and future streamlining, not for immediate automation.

7. Verify each script runs from a clean R session opened via the `.Rproj` file.

**Dependencies:** None (independent of Phase 1, but sequenced after for practical focus).

**Outputs:** All time series analysis scripts consolidated in `R/timeseries/`, running from the `.Rproj`, with documented inputs and outputs. A written description of the current data preparation pipeline from samples to analysis-ready data.

**Notes:** The GAM specifications and seasonal boundaries are well documented in the catalog commit text and Runge et al. (2025) and must be preserved exactly. Streamlining the data preparation pipeline (e.g., digitization tools, structured data entry) is a future effort, not part of this work package.

---

### WP5: Time Series Interactive Viewer (Stations)

**Objective:** Produce per-station, per-variable figures and build a second interactive viewer specifically for time series station data, separate from the SPM biomass viewer.

**Tasks:**

1. For each station (WBTS, CMTS, MWRA sites), generate individual figures for each variable in a format suitable for the interactive viewer. Design a consistent visual style across station types. Establish naming convention: `figures/timeseries/{station}_{variable}_{year}.png` or `figures/timeseries/{station}_{variable}_climatology.png`.

2. Determine what the single-year view means for time series data. Options:
   - Climatology figure with the selected year's observations highlighted
   - Seasonal trend figure showing data through the selected year
   - Both available as a toggle

3. Build a second interactive viewer (same dropdown approach as WP2): dropdowns for station, variable, and year/view type. Include a static reference map showing station locations.

4. Deploy alongside the SPM biomass viewer on GitHub Pages (same `docs/` directory). The landing page links to both viewers.

5. Consider how this viewer will eventually merge into the Quarto site (WP7) or NERACOOS.org.

**Dependencies:** WP4 (scripts consolidated and running). WP3 (GitHub Pages deployment working).

**Outputs:** Station-level figures in `figures/timeseries/`. A second interactive viewer for time series data. Both viewers accessible from the GitHub Pages site.

---

## Phase 3: Satellite SST and Chlorophyll Products

Phase 3 develops a new pipeline for extracting, summarizing, and visualizing satellite-derived SST and chlorophyll-a data at the polygon and stratum level, then integrates the output into the SPM biomass viewer.

### WP6: Satellite SST/Chl Polygon Extraction Pipeline

**Objective:** Build an R workflow to obtain satellite SST and chlorophyll data, extract values within each polygon/stratum, compute summary statistics, and generate figures for the interactive viewer.

**Data source decision — Arctus vs. ERDDAP:**

There are two pathways for obtaining satellite data:

- **Arctus:** Level 4 gap-filled remote sensing data products from an academic/private firm. Potentially higher quality (gap-filled), but depends on an external collaboration, introduces data rights considerations, and may not be sustainable long-term.

- **ERDDAP:** Level 3 gridded data (e.g., MUR SST, MODIS-Aqua/VIIRS chlorophyll composites) available via `rerddap`. Publicly available, no rights issues, stable long-term access, and there are existing scripts for downloading and applying GAMs.

**Recommended approach:** Run a direct comparison test. Extract SST and chlorophyll from both sources for the same polygon(s) and time period. If ERDDAP Level 3 products are comparable to Arctus Level 4 for the polygon-level summary statistics needed here, go with ERDDAP for long-term stability and open access. Gap-filling matters most at the pixel level; at the polygon-mean level, the difference may be small.

**Tasks:**

1. **Comparison test (first task).** For 2-3 representative polygons and a recent year, extract SST and chlorophyll from both Arctus and ERDDAP sources. Compare monthly polygon-level means. Document the comparison and make a go/no-go decision on data source.

2. Identify appropriate ERDDAP datasets (if ERDDAP is selected): MUR SST (JPL, 0.01 degree) for SST; MODIS-Aqua or VIIRS chlorophyll composites for ocean color. Document dataset IDs, spatial/temporal resolution, and coverage period. If Arctus is selected, document the data access arrangement and any usage terms.

3. Write an R script (`R/satellite_data_process.R` or similar) that downloads monthly composites for the study domain, uses `sf` to extract pixel values within each polygon/stratum boundary, and computes summary statistics: mean, SD, pixel count per polygon per month per year.

4. Write summary output to a CSV following the same structure as `DFO_biomass_summary.csv` (polygon key, year, month, mean, SD).

5. Generate visualization figures matching the SPM biomass figure design: all-years seasonal plot per polygon/stratum, and single-year-with-envelope figures for the interactive viewer.

6. Include SBNMS and Stellwagen Bank polygons (same boundaries from WP1).

7. Address satellite chlorophyll data gaps. For the initial release, use raw composites with missing data flagged. Gap-filling (DINEOF, DINCAE, GAMs) can be a later refinement.

8. Extend the SPM biomass interactive viewer (WP2) to include SST and Chlorophyll as additional data types in the dropdown menu. The same polygon/stratum map and year controls apply; only the figure source directory changes.

**Dependencies:** WP1 (polygon boundaries and naming conventions). WP2 (viewer framework). Arctus data access for comparison test.

**Outputs:** Data source decision documented. Satellite extraction pipeline in `R/satellite/`. Summary CSVs in `summaries/`. Satellite figures in `figures/satellite/`. SPM biomass viewer updated to serve satellite products alongside biomass.

**Notes:** This is the largest new development effort. Build incrementally: SST first (simpler, fewer data gaps), then chlorophyll. Monthly composites are the pragmatic starting resolution. The existing rerddap/GAM scripts can serve as a starting point even though polygon-level extraction is new.

---

## Phase 4: Full Website and Automation

Phase 4 wraps the interactive viewers into a broader research website with narrative content and establishes workflows for regular updates.

### WP7: Quarto Website Build

**Objective:** Build a Quarto-based static site that hosts both interactive viewers alongside narrative pages providing scientific background, methods documentation, and results discussion.

**Tasks:**

1. Initialize a Quarto website project in the repository (or a linked repository). Configure for GitHub Pages deployment, replacing the temporary WP3 deployment.

2. Create narrative pages: project overview, study area description, data sources and methods (drawing from the existing background literature and workflow documents), results/discussion for each data type. The landing page should be primarily explanatory, with clear links to the interactive viewers and data subsections.

3. Embed both interactive viewers (SPM biomass and time series stations) as pages or iframes within the Quarto site.

4. Add a data products page describing available downloads: summary CSVs, polygon boundaries, figure archives.

5. Include proper attribution: DFO data product citations (Plourde et al. 2024, Rioux and Lehoux), MBON/WBTS citations (Runge et al. 2025), Thompson et al. (2025) for connectivity context.

6. **Design with portability in mind.** The site may eventually move from GitHub Pages to NERACOOS.org or another institutional host. Keep the architecture simple (static HTML output) so the built site can be dropped into any web server. Avoid deep coupling to GitHub-specific features. Use relative paths for all internal links and assets.

7. Consider two entry points matching the two research contexts: CINAR (eastern GoM/Scotia Shelf, SPM biomass focused) and MBON/CPO (western GoM/SBNMS, time series station focused).

**Dependencies:** WP3 (GitHub Pages working). WP5 and WP6 (at least partially complete for meaningful content).

**Outputs:** A Quarto website with narrative pages and embedded interactive viewers, deployed on GitHub Pages, designed for eventual portability to NERACOOS.org.

---

### WP8: Update Workflow and Automation

**Objective:** Establish documented procedures and, where possible, automation for updating the site when new data become available.

**Tasks:**

1. Document the end-to-end update procedure for each data type: what triggers an update, what scripts to run, what figures are regenerated, and how to push to the site.

2. **SPM biomass updates:** Document the process for incorporating a new DFO data release (request from DFO contacts, download from Poseidon, run Steps 1-4, regenerate figures, commit and push). Reference the DFO dataset readme for download commands and contacts.

3. **Time series station updates:** Document the process for adding new cruise data (following the manual pipeline documented in WP4), rerunning GAMs, and updating figures.

4. **Satellite data updates:** Document the process for extending the time series with new monthly composites.

5. Explore lightweight automation: a master R script (or Makefile) that reruns all pipelines and regenerates all figures in sequence.

6. Consider a GitHub Actions workflow that rebuilds the Quarto site on push to main, so that committing updated figures automatically redeploys the site.

7. Write a `CONTRIBUTING.md` documenting how future collaborators or students can run the pipeline.

**Dependencies:** All previous WPs substantially complete.

**Outputs:** Documented update procedures per data type. A master pipeline script. Optionally, a GitHub Actions workflow for automated site rebuilds.

**Notes:** Full automation is a stretch goal. The pragmatic minimum viable product is a well-documented manual procedure that can be executed in under an hour per update cycle. This work package will be refined iteratively as the pipelines stabilize.

---

## Cross-Cutting Considerations

### Git Workflow

The repo has been initialized and the audit/cleanup committed. Going forward, adopt a simple branching convention: work on feature branches (e.g., `feature/wp1-figure-refactor`) and merge to main when a work package or sub-task is complete. Commit early and often with descriptive messages. Use `.gitignore` to keep raw data (`Bioenergy_3D/`, `processed/`, `polygons/`) out of the repo while tracking scripts, boundary data, summaries, and the site.

### Post-Change Audit

After WP1 is complete (or after any major pipeline modification), run a follow-up audit to verify the pipeline state, confirm new outputs are correct, and update AUDIT.md. The audit should be lightweight and focused on changes since the last audit, not a full re-audit.

### Large File Strategy

The ~300 PNG figures for the initial SPM biomass viewer will total roughly 60 MB. This is within GitHub's guidelines but warrants monitoring. If the figure count grows substantially as satellite and time series products are added, options include: GitHub LFS, hosting figures on an institutional server (NERACOOS), or using a CDN. For now, committing directly is fine.

### Connectivity / Particle Tracking

The task notes mention adding connectivity to the site. The Thompson et al. (2025) FVCOM particle tracking work provides the scientific basis. This is not included as a discrete work package because the figure products and appropriate web representation need further scoping. When ready, connectivity metrics or figures could be added as an additional data type in either viewer following the same pattern.

### Variance Metrics for Polygon Summaries

The current pipeline reports mean and SD of biomass across grid points within a polygon. This is a spatial summary across model grid points, not a true ecological variance metric. For the website and data products, report mean and SD clearly labeled as spatial summary statistics. A more nuanced discussion of what this variance represents belongs in the narrative methods page (WP7). Alternative metrics (coefficient of variation, density-based variance) can be explored as a refinement within WP1 but should not block figure production.

### Projection and Coordinate System

The pipeline uses `sf` with S2 disabled (planar geometry) for polygon assignment. This is appropriate for the study domain and consistent with the original MATLAB implementation. No changes recommended, but the choice should be documented in the methods narrative (WP7).

### 2024 Data Extent

The 2024 DFO data release has a slightly reduced spatial extent (Northumberland Strait and upper Bay of Fundy removed, western boundary shifted). The pipeline handles this silently because points outside polygons receive no assignment. This should be noted in the site metadata and methods documentation so users understand that polygon-level summaries for 2024 may have fewer contributing grid points in some regions.

### Portability to NERACOOS.org

The Quarto site (WP7) should be designed so the built output (static HTML + assets) can be served from any web server, not just GitHub Pages. This means: relative paths for all internal links, no GitHub-specific JavaScript, and self-contained figure directories. If the site moves to NERACOOS.org, it should be a matter of copying the built `_site/` directory to the new host.

---

## Work Package Dependencies

```
WP1 (figures) ──────────┐
    ↕ parallel           ├──→ WP3 (deploy) ──→ WP7 (Quarto site)
WP2 (biomass viewer) ───┘                         ↑
                                                   │
WP4 (station scripts) ──→ WP5 (station viewer) ───┘
                                                   │
WP6 (satellite) ──────────────────────────────────┘
                                                   │
                                              WP8 (automation)
```

- WP1 and WP2 can proceed in parallel; WP2 needs only the naming convention from WP1 to start.
- WP3 requires WP1 + WP2.
- WP4 is independent and can start any time.
- WP5 requires WP4 + WP3.
- WP6 requires WP1 (polygon definitions) + WP2 (viewer framework).
- WP7 requires WP3 and benefits from WP5/WP6 being partially done.
- WP8 is a capstone that benefits from all others being complete.
