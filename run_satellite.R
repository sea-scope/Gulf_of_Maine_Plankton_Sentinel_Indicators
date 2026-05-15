## run_satellite.R
##
## Top-level orchestrator for the WP6 satellite pipeline. Sources the four
## R/04_satellite_products/ layers in order, then runs:
##
##   1. ingest    — download per-polygon NetCDFs for every (variable, year,
##                  geography_set) combination in scope. Resumable; cached
##                  files are skipped automatically.
##   2. summary   — extract + composite across the full record, write
##                  summaries/satellite/satellite_summary.csv.
##   3. plots     — climatology PNGs in plots/satellite/.
##
## Open GoM_Plankton_Sentinel_Indicators.Rproj before sourcing so that
## getwd() resolves to the repo root.
##
## Time budget: a full first-run ingest across stations + CINAR + CPO and
## both variables (chl 1997-2025, SST 1981-2025) is estimated at 8-12 hours
## on a typical NEFSC ERDDAP day. Resumable on interrupt.
##
## Scope controls at the top of this file:
##   GEOGRAPHY_SETS — which sets to process (defaults: all wired-up sets)
##   VARIABLES      — which variables to ingest/summarize/plot
##   YEARS          — restrict to a subset of years (NULL = each variable's
##                    full configured range)
##   SKIP_INGEST    — TRUE to skip the long download step (useful when the
##                    cache is already populated and you just want to
##                    re-summarize or re-plot)
##
## To run a small validation against the existing cache only:
##   GEOGRAPHY_SETS <- c("stations", "cinar")
##   VARIABLES      <- "chlor_a"
##   YEARS          <- 2020
##   SKIP_INGEST    <- TRUE
##   source("run_satellite.R")

# ---------------------------------------------------------------------------
# Scope controls — edit these before sourcing for a partial run
# ---------------------------------------------------------------------------
GEOGRAPHY_SETS <- NULL    # NULL = all wired-up sets (stations, cinar, cpo)
VARIABLES      <- c("chlor_a", "sst")
YEARS          <- NULL    # NULL = each variable's full configured range
SKIP_INGEST    <- FALSE

# ---------------------------------------------------------------------------
# Source the pipeline layers (each sources its predecessors via its top-of-
# file guard, so order here is for clarity).
# ---------------------------------------------------------------------------
source("R/04_satellite_products/satellite_config.R")
source("R/04_satellite_products/satellite_ingest.R")
source("R/04_satellite_products/satellite_extract.R")
source("R/04_satellite_products/satellite_composite.R")
source("R/04_satellite_products/satellite_summary.R")
source("R/04_satellite_products/plot_satellite_climatology.R")


if (is.null(GEOGRAPHY_SETS)) {
  GEOGRAPHY_SETS <- names(satellite_config$geography_sets)
}


# ---------------------------------------------------------------------------
# 1) Ingest — per-polygon NetCDFs, resumable, skips cached
# ---------------------------------------------------------------------------
if (isTRUE(SKIP_INGEST)) {
  cat("\n[run_satellite] SKIP_INGEST = TRUE — using existing cache only\n")
} else {
  cat("\n[run_satellite] === Ingest ===\n")
  ingest_t0 <- Sys.time()

  for (set_name in GEOGRAPHY_SETS) {
    for (vbl in VARIABLES) {
      vcfg <- satellite_config[[vbl]]
      if (is.null(vcfg)) next
      yr_range <- if (is.null(YEARS)) {
        vcfg$year_start:vcfg$year_end
      } else {
        intersect(YEARS, vcfg$year_start:vcfg$year_end)
      }
      for (yr in yr_range) {
        ingest_satellite(vbl, yr, set_name)
      }
    }
  }

  cat(sprintf("[run_satellite] ingest wall time: %.1f min\n",
              as.numeric(difftime(Sys.time(), ingest_t0, units = "mins"))))
}


# ---------------------------------------------------------------------------
# 2) Summary — extract + composite + write summaries/satellite/satellite_summary.csv
# ---------------------------------------------------------------------------
cat("\n[run_satellite] === Summary ===\n")
summary_t0 <- Sys.time()

write_satellite_summary(
  geography_sets = GEOGRAPHY_SETS,
  variables      = VARIABLES,
  years          = YEARS
)

cat(sprintf("[run_satellite] summary wall time: %.1f min\n",
            as.numeric(difftime(Sys.time(), summary_t0, units = "mins"))))


# ---------------------------------------------------------------------------
# 3) Plots — climatology PNGs
# ---------------------------------------------------------------------------
cat("\n[run_satellite] === Plots ===\n")
plot_t0 <- Sys.time()

plot_satellite_climatology(
  geography_sets = GEOGRAPHY_SETS,
  variables      = VARIABLES,
  years          = YEARS
)

cat(sprintf("[run_satellite] plot wall time: %.1f min\n",
            as.numeric(difftime(Sys.time(), plot_t0, units = "mins"))))

cat("\n[run_satellite] === Satellite pipeline complete ===\n")
