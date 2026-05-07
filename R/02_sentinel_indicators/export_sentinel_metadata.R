# =============================================================================
# Sentinel Indicators — Metadata Export
#
# Writes plots/sentinel/sentinel_metadata.json listing all available
# (station, variable, plottype) combinations for the viewer to read.
# Also writes the dashboard CSV to its canonical location.
# =============================================================================

library(jsonlite)

if (!exists("station_config")) {
  source(file.path("R", "02_sentinel_indicators", "station_config.R"))
}

# =============================================================================
# export_sentinel_metadata()
#
# Scans the sentinel plots directory for existing PNGs and builds a metadata
# JSON listing available combinations.
#
# Parameters:
#   plot_dir    — base plots directory (default: plots/sentinel)
#   stations    — character vector of station IDs (default: all in config)
#
# Returns: the metadata list (invisible)
# =============================================================================

export_sentinel_metadata <- function(
    plot_dir = file.path("plots", "sentinel"),
    stations = names(station_config)
) {
  variables <- c("CI", "CSI", "DW")
  plot_types <- c("phenology", "seasonal", "anomaly")

  entries <- list()

  for (stn in stations) {
    cfg <- station_config[[stn]]

    for (var in variables) {
      for (pt in plot_types) {
        # CSI has no anomaly plot
        if (var == "CSI" && pt == "anomaly") next

        fname <- paste0(stn, "_", var, "_", pt, ".png")
        fpath <- file.path(plot_dir, stn, fname)

        if (file.exists(fpath)) {
          entries[[length(entries) + 1]] <- list(
            station   = stn,
            variable  = var,
            plot_type = pt,
            file      = file.path(stn, fname),
            seasons   = names(cfg$season_boundaries)
          )
        }
      }

      # Anomaly bar charts: one PNG per season (CI and DW only)
      if (var != "CSI") {
        for (ssn in names(cfg$season_boundaries)) {
          fname <- paste0(stn, "_", var, "_anomaly_bar_", ssn, ".png")
          fpath <- file.path(plot_dir, stn, fname)
          if (file.exists(fpath)) {
            entries[[length(entries) + 1]] <- list(
              station   = stn,
              variable  = var,
              plot_type = "anomaly_bar",
              file      = file.path(stn, fname),
              seasons   = list(ssn)
            )
          }
        }
      }
    }
  }

  metadata <- list(
    product     = "sentinel_indicators",
    description = "WBTS and CMTS plankton sentinel indicator plots",
    stations    = stations,
    variables   = variables,
    plot_types  = c(plot_types, "anomaly_bar"),
    entries     = entries
  )

  out_path <- file.path(plot_dir, "sentinel_metadata.json")
  writeLines(toJSON(metadata, auto_unbox = TRUE, pretty = TRUE), out_path)
  cat("  Wrote:", out_path, "(", length(entries), "entries )\n")

  invisible(metadata)
}
