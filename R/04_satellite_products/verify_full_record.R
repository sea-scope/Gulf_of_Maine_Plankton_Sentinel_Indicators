# =============================================================================
# WP6 — Post-Ingest Verification
#
# Run from project root after `source("run_satellite.R")` completes:
#   source("R/04_satellite_products/verify_full_record.R")
#
# Read-only. No downloads, no writes. Reports on:
#   1. NetCDF cache completeness — file count per (set, variable), missing
#      polygon-years, files smaller than the resumability threshold.
#   2. Summary + daily CSV health — row counts, per-(polygon, variable)
#      year coverage, gaps versus the expected year range.
#   3. Sparse-flag distribution — what fraction of windows are flagged
#      sparse per (set, variable). Expected: stations/SST all-sparse,
#      stations/chl mostly non-sparse, CINAR/CPO mostly non-sparse.
#   4. PNG counts per (set, variable).
#   5. Seasonal-shape sanity — GMB150 2020 chl peak should still land at
#      window DOY 241 (Session B and Session C reference value).
#   6. Failed extracts — polygons that appear in the cache but have no
#      valid rows in the summary (suggests extract error).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("R/04_satellite_products/satellite_config.R")

# -----------------------------------------------------------------------------
# 1) NetCDF cache completeness
# -----------------------------------------------------------------------------
cat("\n=== 1) Cache completeness ===\n")

cache_root <- satellite_config$paths$raw_dir
sets <- names(satellite_config$geography_sets)

cache_inventory <- list()
for (set_name in sets) {
  set_dir <- file.path(cache_root, set_name)
  if (!dir.exists(set_dir)) {
    cat(sprintf("  [%s] NO CACHE DIR — set was skipped or ingest never reached it\n", set_name))
    next
  }
  files <- list.files(set_dir, pattern = "\\.nc$", full.names = TRUE)
  if (length(files) == 0) {
    cat(sprintf("  [%s] 0 NetCDFs cached\n", set_name))
    next
  }
  szs <- file.info(files)$size
  # Anchor on the suffix `_(chlor_a|sst)_<year>.nc` so polygon_ids with
  # internal underscores (e.g. EM_35, EM_40) parse correctly.
  parsed <- regmatches(basename(files),
                       regexec("^(.+)_(chlor_a|sst)_(\\d{4})\\.nc$",
                               basename(files)))
  parsed <- do.call(rbind, lapply(parsed, function(x) {
    if (length(x) == 4) x[2:4] else c(NA, NA, NA)
  }))
  colnames(parsed) <- c("polygon_id", "variable", "year")
  inv <- data.frame(
    geography_set = set_name,
    polygon_id    = parsed[, "polygon_id"],
    variable      = parsed[, "variable"],
    year          = as.integer(parsed[, "year"]),
    size_bytes    = szs,
    stringsAsFactors = FALSE
  )
  cache_inventory[[set_name]] <- inv

  cat(sprintf("  [%s] %d NetCDFs cached (chl: %d, sst: %d) ; %.1f MB total\n",
              set_name, nrow(inv),
              sum(inv$variable == "chlor_a", na.rm = TRUE),
              sum(inv$variable == "sst", na.rm = TRUE),
              sum(szs) / 1024 / 1024))

  small <- inv[!is.na(inv$size_bytes) & inv$size_bytes < 10 * 1024L, ]
  if (nrow(small) > 0) {
    cat(sprintf("    WARN: %d file(s) below 10 KB (possible truncated download):\n",
                nrow(small)))
    print(small[, c("polygon_id", "variable", "year", "size_bytes")],
          row.names = FALSE)
  }
}

cache_df <- if (length(cache_inventory) > 0) {
  bind_rows(cache_inventory)
} else {
  data.frame()
}

# Expected (variable, year) ranges per config
chl_years <- satellite_config$chlor_a$year_start:satellite_config$chlor_a$year_end
sst_years <- satellite_config$sst$year_start:satellite_config$sst$year_end

cat("\nMissing (polygon, variable, year) combinations (cache vs config year range):\n")
missing_combos <- list()
for (set_name in sets) {
  set_entry <- satellite_config$geography_sets[[set_name]]
  if (is.null(set_entry) || is.null(set_entry$sf)) next
  pids <- as.character(set_entry$sf$polygon_id)
  for (vbl in c("chlor_a", "sst")) {
    yrs <- if (vbl == "chlor_a") chl_years else sst_years
    expected <- expand.grid(polygon_id = pids, year = yrs,
                            stringsAsFactors = FALSE)
    have <- cache_df %>%
      filter(geography_set == set_name, variable == vbl) %>%
      select(polygon_id, year)
    miss <- anti_join(expected, have,
                      by = c("polygon_id", "year"))
    if (nrow(miss) > 0) {
      miss$geography_set <- set_name
      miss$variable      <- vbl
      missing_combos[[paste(set_name, vbl, sep = "/")]] <- miss
      cat(sprintf("  [%s / %s] missing %d / %d combinations:\n",
                  set_name, vbl, nrow(miss), nrow(expected)))
      # Show first few
      print(head(miss[, c("polygon_id", "year")], 10), row.names = FALSE)
      if (nrow(miss) > 10) cat(sprintf("    ... (%d more)\n", nrow(miss) - 10))
    }
  }
}
if (length(missing_combos) == 0L) {
  cat("  (none — cache matches expected coverage)\n")
}


# -----------------------------------------------------------------------------
# 2) Summary + daily CSV health
# -----------------------------------------------------------------------------
cat("\n=== 2) Summary + daily CSV ===\n")

summary_csv <- satellite_config$paths$summary_csv
daily_csv   <- satellite_config$paths$daily_csv

if (!file.exists(summary_csv)) {
  cat(sprintf("  MISSING: %s\n", summary_csv))
} else {
  s <- read_csv(summary_csv, show_col_types = FALSE)
  cat(sprintf("  %s : %d rows, %d cols (%.1f MB)\n",
              summary_csv, nrow(s), ncol(s),
              file.info(summary_csv)$size / 1024 / 1024))
  cat("  Row counts by (geography_set, variable):\n")
  print(as.data.frame(count(s, geography_set, variable)))
  cat("  Year range by (geography_set, variable):\n")
  print(as.data.frame(s %>% group_by(geography_set, variable) %>%
                        summarise(yr_min = min(year), yr_max = max(year),
                                  n_years = dplyr::n_distinct(year),
                                  .groups = "drop")))
}

if (!file.exists(daily_csv)) {
  cat(sprintf("  MISSING: %s\n", daily_csv))
} else {
  d <- read_csv(daily_csv, show_col_types = FALSE)
  cat(sprintf("\n  %s : %d rows, %d cols (%.1f MB)\n",
              daily_csv, nrow(d), ncol(d),
              file.info(daily_csv)$size / 1024 / 1024))
  cat("  Row counts by (geography_set, variable):\n")
  print(as.data.frame(count(d, geography_set, variable)))
}


# -----------------------------------------------------------------------------
# 3) Sparse-flag distribution
# -----------------------------------------------------------------------------
if (exists("s")) {
  cat("\n=== 3) Sparse-flag distribution ===\n")
  cat("  By (geography_set, variable):\n")
  print(as.data.frame(s %>%
    group_by(geography_set, variable) %>%
    summarise(n_total   = dplyr::n(),
              n_sparse  = sum(sparse),
              n_nonsparse = sum(!sparse),
              pct_sparse = round(100 * mean(sparse), 1),
              .groups   = "drop")))
}


# -----------------------------------------------------------------------------
# 4) PNG counts
# -----------------------------------------------------------------------------
cat("\n=== 4) PNG counts ===\n")
plot_root <- satellite_config$paths$plot_dir
for (set_name in sets) {
  set_dir <- file.path(plot_root, set_name)
  if (!dir.exists(set_dir)) {
    cat(sprintf("  [%s] no plot dir\n", set_name))
    next
  }
  pngs <- list.files(set_dir, pattern = "\\.png$", full.names = TRUE)
  by_kind <- table(grepl("_overview\\.png$", pngs))
  cat(sprintf("  [%s] %d PNGs (overviews: %d, per-year: %d)\n",
              set_name, length(pngs),
              sum(grepl("_overview\\.png$", pngs)),
              sum(!grepl("_overview\\.png$", pngs))))
}


# -----------------------------------------------------------------------------
# 5) Seasonal-shape regression check: GMB150 chl 2020
# -----------------------------------------------------------------------------
if (exists("s")) {
  cat("\n=== 5) GMB150 2020 chlor_a seasonal peak (regression check) ===\n")
  gmb_2020 <- s %>% filter(geography_set == "cinar",
                            polygon_id    == "GMB150",
                            variable      == "chlor_a",
                            year          == 2020,
                            !sparse)
  if (nrow(gmb_2020) == 0) {
    cat("  No non-sparse GMB150 chl 2020 rows — unexpected, investigate.\n")
  } else {
    i_max <- which.max(gmb_2020$value_mean)
    cat(sprintf("  Peak %.2f mg m^-3 at window DOY %d (Session B/C reference: ~2.60-2.67 at DOY 241)\n",
                gmb_2020$value_mean[i_max], gmb_2020$window_doy_start[i_max]))
  }
}


# -----------------------------------------------------------------------------
# 6) Polygons in cache but missing from summary (extract failures)
# -----------------------------------------------------------------------------
if (exists("s") && nrow(cache_df) > 0) {
  cat("\n=== 6) Cache-vs-summary consistency ===\n")
  cache_combos <- cache_df %>%
    distinct(geography_set, polygon_id, variable, year)
  summary_combos <- s %>%
    distinct(geography_set, polygon_id, variable, year)
  orphan_cache <- anti_join(cache_combos, summary_combos,
                            by = c("geography_set", "polygon_id",
                                   "variable", "year"))
  if (nrow(orphan_cache) > 0) {
    cat(sprintf("  WARN: %d (set, polygon, variable, year) combinations are in cache but absent from summary CSV.\n",
                nrow(orphan_cache)))
    cat("  This usually means extract or composite errored on those files.\n")
    print(head(as.data.frame(orphan_cache), 20), row.names = FALSE)
    if (nrow(orphan_cache) > 20) {
      cat(sprintf("  ... (%d more)\n", nrow(orphan_cache) - 20))
    }
  } else {
    cat("  Cache and summary match — no orphans.\n")
  }
}


cat("\n=== Post-ingest verification complete ===\n")
cat("Visual spot-checks recommended:\n")
cat("  - plots/satellite/cinar/cinar_GMB150_chlor_a_2020.png\n")
cat("    (focus year on top of multi-year climatology — the grey ribbons should now have real width)\n")
cat("  - plots/satellite/cinar/cinar_GMB150_chlor_a_overview.png\n")
cat("    (all years overlaid — confirm seasonal pattern persists across years)\n")
cat("  - plots/satellite/cpo/cpo_SBNMS_chlor_a_2020.png  (a CPO polygon you haven't seen yet)\n")
cat("  - plots/satellite/cinar/cinar_GMB150_sst_2020.png  (first full SST signal)\n")
