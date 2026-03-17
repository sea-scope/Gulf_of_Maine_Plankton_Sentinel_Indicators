# Handoff Prompt — SPM Calanus Biomass Visualization

**Repo:** `C:\Users\camer\Desktop\SPM_calanus_biomass\`
**Open** `SPM_calanus_biomass.Rproj` before running anything in R.

---

## What was done (session 1)

### 1. SBNMS added as 9th CINAR polygon
- `R/Data_layer_Polygons.R` — SBNMS (CINAR_poly = 9) loaded from `data/SBNMS.csv`, no clipping needed.
- `R/DFO_data_polygon_summary.R` — `"9" = "SBNMS"` added to `cinar_names` lookup.
- Pipeline was re-run from Step 2 onward; `summaries/DFO_biomass_summary.csv` now includes SBNMS rows.

### 2. Bathymetry stats added to summary
- `R/DFO_data_polygon_summary.R` — `mean_bathy` and `sd_bathy` columns added to `summarise_poly()`.
- `bathymetry` added to `required_cols`.

---

## What was done (session 2)

### 3. Sample size columns added to summary
- `R/DFO_data_polygon_summary.R` — added `n_0_80` (count of non-NA shallow grid points) and `n_below_80` (count of non-NA deep grid points) to `summarise_poly()`.
- Both excluded from rounding in the mutate step.

### 4. Visualization scripts updated (CINAR + EcoMon)
Both `R/DFO_biomass_visualization_CINAR.R` and `R/DFO_biomass_visualization_EcoMon.R`:

**Per-year climatology figures** (4-layer design):
- Layer 0 (back): historical range ribbon, `grey80`.
- Layer 1: climatological mean ± 1 SD ribbon, `grey50`.
- Layer 2: climatological mean dashed line, `grey30`.
- Layer 3 (front): focus year bold orange line + error bars.
- **Legend removed**, **year in title**, **sample size annotation**, **n < 22 placeholder**, **no caption** (caption moved to HTML viewer).

**Overview figures** are unchanged (all years overlaid, viridis plasma, legend at bottom).

### 5. Metadata JSON export
- `R/export_viewer_metadata.R` (Step 4c) — writes `plots/stations_metadata.json`.
- 42 entries (9 CINAR + 33 EcoMon), each with `id`, `label`, `type`, `min_year`, `max_year`.

### 6. run_pipeline.R updated
- Step 4c added for `export_viewer_metadata.R`.

### 7. Summary CSV and all plots regenerated
- User ran Steps 3, 4a, 4b. All PNGs and summary CSV are current.

---

## What was done (session 3 — current)

### 8. Viewer split into 3 pages + landing page
Replaced the single `index.html` with a multi-page static site:

| File | Content | Map image |
|---|---|---|
| `index.html` | Landing page with NE shelf background, calanus_trans logo, links to 3 viewers | — |
| `cinar.html` | CINAR polygons (8 regions, excludes SBNMS) | `figures/DFO_region_map_CINAR.png` |
| `ecomon.html` | All 33 EcoMon strata | `figures/EcoMon_strata_map.png` |
| `cpo.html` | CPO project: SBNMS + EcoMon strata 35, 36, 37, 40 | `figures/DFO_region_map_SBNMS.png` |

**Layout (all viewer pages):**
- Top: nav bar (Home / CINAR / EcoMon / CPO) + controls bar (region dropdown, depth dropdown, year slider).
- Left panel (70%): map image on top, biomass plot below. Scrolls independently.
- Right panel (30%): descriptive text (About, Data Source, Regional Biomass Indices, How to Read the Plot, Reference). Scrolls independently.
- Missing images show "No data available for this combination."
- Each page has embedded JSON fallback for local `file://` access.

**Landing page (`index.html`):**
- `figures/NE shelf.png` as full-page background with dark overlay.
- `figures/calanus_trans.png` (440px) above title.
- Three cards linking to CINAR, EcoMon, CPO pages.

### 9. Figure caption / descriptive text added
Extensive methodology text added to right panel of all viewer pages, covering:
- About These Figures — what the plot shows
- Data Source — AZMP/EcoMon surveys, CIV-CVI stages, GAMMs, GLORYS12v1 at ~9 km (0.083° × 0.083°), abundance-to-biomass conversion
- Regional Biomass Indices — spatial aggregation into EcoMon strata and CINAR polygons, depth layers (0-80 m / >80 m / total), unit conversion
- How to Read the Plot — table explaining all four visual layers, SDM vs. observation clarification, bathymetry annotation
- Reference — Plourde et al. (2024)

### 10. New images added to figures/
- `figures/NE shelf.png` — Northeast Shelf satellite/map image (landing page background)
- `figures/calanus_trans.png` — Calanus illustration with transparent background (landing page logo)

---

## Current state of uncommitted changes

All changes are uncommitted. Nothing has been pushed. Key files:

**Modified (tracked):**
```
 M  R/DFO_biomass_visualization_CINAR.R
 M  R/DFO_biomass_visualization_EcoMon.R
 M  R/DFO_data_polygon_summary.R
 M  R/Data_layer_Polygons.R
 M  R/DFO_CINAR_polygon_map.R
 M  run_pipeline.R
 M  summaries/DFO_biomass_summary.csv
 D  AUDIT.md  (moved to Context/AUDIT.md by user)
 D  figures/Biomass_interannual_36_37.png
 D  figures/CINAR_all_regions_deep.png
 D  figures/CINAR_all_regions_shallow.png
```

**New (untracked):**
```
 ??  index.html
 ??  cinar.html
 ??  ecomon.html
 ??  cpo.html
 ??  R/export_viewer_metadata.R
 ??  R/sandbox_ecomon36.R
 ??  Context/
 ??  plots/  (overview + yearly PNGs + stations_metadata.json)
 ??  figures/NE shelf.png
 ??  figures/calanus_trans.png
 ??  work_packages.md
 ??  HANDOFF.md
 ??  figures/New folder/
```

---

## What remains to do

### A. Commit all changes
Suggested commit phases:

1. **Data pipeline** — `R/Data_layer_Polygons.R`, `R/DFO_data_polygon_summary.R`, `summaries/DFO_biomass_summary.csv`
   > "Add SBNMS polygon; add bathymetry and sample size stats to summary"

2. **Visualization + metadata** — both viz scripts, `R/export_viewer_metadata.R`, `R/sandbox_ecomon36.R`, `run_pipeline.R`
   > "Rewrite biomass viz: per-polygon PNGs, n<22 placeholder, metadata export"

3. **HTML viewer** — `index.html`, `cinar.html`, `ecomon.html`, `cpo.html`
   > "Add multi-page biomass viewer with maps and methodology text"

4. **Generated plots** — `plots/` directory (overview + yearly PNGs + `stations_metadata.json`)
   > "Add generated biomass visualization PNGs and metadata JSON"

5. **Supporting files** — `Context/`, `figures/NE shelf.png`, `figures/calanus_trans.png`, `HANDOFF.md`, `work_packages.md`
   > "Add context docs, map images, and handoff notes"

Do NOT force-push or rewrite history. Do NOT push until GitHub Pages setup is confirmed.

### B. Set up GitHub Pages
Deploy the viewer as a static site on GitHub Pages:

1. **Create the GitHub repo** (if it doesn't already exist):
   ```bash
   gh repo create SPM_calanus_biomass --public --source=. --push
   ```
   Or if the repo already exists, just push:
   ```bash
   git remote add origin <url>   # if needed
   git push -u origin main
   ```

2. **Enable GitHub Pages** — deploy from the `main` branch, root (`/`) directory:
   ```bash
   gh api repos/{owner}/SPM_calanus_biomass/pages -X POST \
     -f source.branch=main -f source.path=/
   ```
   Or do it manually: repo Settings → Pages → Source: Deploy from branch → `main` / `/ (root)`.

3. **Verify** — the site should be live at `https://<username>.github.io/SPM_calanus_biomass/`.
   - `index.html` → landing page
   - `cinar.html`, `ecomon.html`, `cpo.html` → viewer pages
   - `plots/` and `figures/` served as static assets

4. **Test** — confirm that:
   - All three viewer pages load and images update with controls
   - Metadata JSON loads via `fetch()` (not the embedded fallback)
   - Map images display on all pages
   - Landing page background and logo render correctly
   - "No data available" message appears for missing depth/year combos

### C. Remaining cleanup (not urgent)
- `R/DFO_CINAR_polygon_map.R` — bathymetry re-downloads every run (TODO: add caching).
- `R/sandbox_ecomon36.R` — decide whether to keep in repo or `.gitignore`.
- `figures/New folder/` — user-created empty folder; clean up or `.gitignore`.
- Old deleted figures (`Biomass_interannual_36_37.png`, `CINAR_all_regions_*.png`) — confirm no longer needed.

---

## File reference

| Pipeline step | Script | Purpose |
|---|---|---|
| Step 1 | `R/DFO_data_process.R` | RDS → depth-integrated CSVs in `processed/` |
| Step 2 | `R/Data_layer_Polygons.R` | Point-in-polygon assignment → `polygons/` |
| Step 3 | `R/DFO_data_polygon_summary.R` | Polygon-level summary → `summaries/DFO_biomass_summary.csv` |
| Step 4a | `R/DFO_biomass_visualization_CINAR.R` | CINAR biomass plots → `plots/cinar_*/` |
| Step 4b | `R/DFO_biomass_visualization_EcoMon.R` | EcoMon biomass plots → `plots/ecomon_*/` |
| Step 4c | `R/export_viewer_metadata.R` | Viewer metadata → `plots/stations_metadata.json` |
| Step 4e | `R/DFO_CINAR_polygon_map.R` | CINAR polygon QC map |
| Step 4f | `R/DFO_EcoMon_strata_map.R` | EcoMon strata map |
| Step 4g | `R/DFO_region_map.R` | Publication region maps (CINAR + SBNMS) |
| Sandbox | `R/sandbox_ecomon36.R` | Interactive plot tuning |
| Viewer | `index.html` | Landing page |
| Viewer | `cinar.html` | CINAR polygon viewer (excludes SBNMS) |
| Viewer | `ecomon.html` | EcoMon strata viewer (all 33 strata) |
| Viewer | `cpo.html` | CPO project viewer (SBNMS + strata 35, 36, 37, 40) |
| Master | `run_pipeline.R` | Steps 1→2→3→4a→4b→4c→4e→4f→4g |

### Output directory structure
```
index.html                  — Landing page (NE shelf background + calanus logo)
cinar.html                  — CINAR viewer
ecomon.html                 — EcoMon viewer
cpo.html                    — CPO viewer
plots/
  stations_metadata.json    — Viewer metadata (42 entries)
  cinar_overview/           — CINAR_<key>_{shallow,deep,total}.png
  cinar_yearly/             — CINAR_<DisplayName>_<year>_{shallow,deep,total}.png
  ecomon_overview/          — EcoMon_stratum_<id>_{shallow,deep,total}.png
  ecomon_yearly/            — EcoMon_<id>_<year>_{shallow,deep,total}.png
figures/
  DFO_region_map_CINAR.png  — CINAR publication map
  DFO_region_map_SBNMS.png  — SBNMS/GoM region map
  EcoMon_strata_map.png     — EcoMon strata map
  CINAR_polygons_map.png    — CINAR polygon QC map
  NE shelf.png              — Landing page background
  calanus_trans.png         — Landing page logo
```

### Key parameters
- Biomass units: g m⁻² (converted from mg m⁻² at load time, ÷ 1000)
- Placeholder cutoff: n < 22 data points per month
- n_col mapping: shallow/total → `n_0_80`, deep → `n_below_80`
- Focus year color: `#D55E00` (orange)
- Climatological mean: dashed grey30 line
- Envelopes: grey50 (±1 SD) over grey80 (historical range)
- GLORYS12v1 resolution: ~9 km (0.083° × 0.083°)
- SDM source: Plourde et al. (2024), DFO CSAS Res. Doc. 2024/039
