# =============================================================================
# Satellite Products — Summary CSV Layer
#
# Orchestrates extract + composite across all (variable, year, geography_set)
# combinations and writes TWO durable downstream-consumer products:
#
#   1. summaries/satellite/satellite_summary.csv (8-day composites)
#      geography_set, polygon_id, variable, year, window_num, window_doy_start,
#      value_mean, value_sd, n_valid_pixels, n_days_with_data, n_pixel_obs, sparse
#
#   2. summaries/satellite/satellite_daily.csv (per polygon-day extract output)
#      geography_set, polygon_id, variable, date, year, doy, value_mean,
#      sum_w, sum_wx, sum_wxx, n_valid_pixels
#
# The daily CSV preserves the upstream-of-composite extract output so
# downstream GAM workflows that operate on daily polygon-means (e.g. CT's
# `Context/satellite/wbts_chl_analysis.R`) don't have to re-run extract or
# re-do the 8-12 h ingest. The 8-day summary CSV is what the climatology
# plots consume.
#
# Behavior:
#   - Loops over geography_set x variable x year.
#   - Skips (set, variable, year) combinations whose per-polygon NetCDF cache
#     is entirely absent (no polygons cached -> no rows produced).
#   - Skips year ranges outside `config[[variable]]$year_start..year_end`.
#   - Append-vs-replace: by default writes single CSVs containing all rows
#     in one pass. Use `write_satellite_summary(years = <subset>)` to limit
#     scope (useful for verification on the Session B/C cache).
#
# Memory note: a full record across stations + CINAR + CPO x both variables
# is ~150k rows for the 8-day file and ~400k rows for the daily file. Both
# fit easily in memory. No chunked-write path needed.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

if (!exists("satellite_config")) {
  source(file.path("R", "04_satellite_products", "satellite_config.R"))
}
if (!exists("extract_satellite")) {
  source(file.path("R", "04_satellite_products", "satellite_extract.R"))
}
if (!exists("composite_to_8day")) {
  source(file.path("R", "04_satellite_products", "satellite_composite.R"))
}


#' Assemble the satellite summary + daily CSVs by looping over (set, variable, year)
#'
#' @param geography_sets Character vector. Defaults to all wired-up sets.
#' @param variables      Character vector. Defaults to c("chlor_a", "sst").
#' @param years          Integer vector. If NULL, uses each variable's full
#'   `year_start:year_end` range from `config`.
#' @param config         List. Defaults to satellite_config.
#' @param out_csv        8-day summary CSV path. Defaults to `config$paths$summary_csv`.
#' @param daily_csv      Daily polygon-mean CSV path. Defaults to
#'   `config$paths$daily_csv`. Set to NULL to skip writing the daily CSV.
#' @param write          Logical. If FALSE, returns the assembled frames
#'   without writing (used by validators).
#'
#' @return Invisibly, a list with `summary` (8-day data frame) and `daily`
#'   (per-day data frame). Writes `out_csv` and `daily_csv` as side effects
#'   when `write = TRUE`.
write_satellite_summary <- function(geography_sets = NULL,
                                    variables      = c("chlor_a", "sst"),
                                    years          = NULL,
                                    config         = satellite_config,
                                    out_csv        = config$paths$summary_csv,
                                    daily_csv      = config$paths$daily_csv,
                                    write          = TRUE) {

  if (is.null(geography_sets)) {
    geography_sets <- names(config$geography_sets)
  }

  summary_rows <- list()
  daily_rows   <- list()

  for (set_name in geography_sets) {
    set_entry <- config$geography_sets[[set_name]]
    if (is.null(set_entry) || is.null(set_entry$sf)) {
      message(sprintf("[summary] skip set '%s' (not wired up)", set_name))
      next
    }

    for (vbl in variables) {
      vcfg <- config[[vbl]]
      if (is.null(vcfg) || is.null(vcfg$dataset_id)) {
        message(sprintf("[summary] skip variable '%s' (no config)", vbl))
        next
      }

      yr_range <- if (is.null(years)) {
        vcfg$year_start:vcfg$year_end
      } else {
        intersect(years, vcfg$year_start:vcfg$year_end)
      }
      if (length(yr_range) == 0L) next

      for (yr in yr_range) {
        daily_df <- tryCatch(
          extract_satellite(vbl, yr, set_name, config = config),
          error = function(e) {
            warning(sprintf("[summary] extract FAILED %s/%s/%d: %s",
                            set_name, vbl, yr, conditionMessage(e)))
            NULL
          }
        )

        if (is.null(daily_df) || nrow(daily_df) == 0L) {
          message(sprintf("[summary] no data %s/%s/%d (cache empty?) — skipping",
                          set_name, vbl, yr))
          next
        }

        # Stash the daily rows for the daily CSV. Rename variable_mean ->
        # value_mean and add year/doy convenience columns for downstream use.
        # Coerce date to plain Date (no attached dim) and pre-emptively drop
        # any row where date is NA — keeps readr::write_csv from tripping on
        # the column type later.
        daily_for_csv <- daily_df |>
          mutate(date = as.Date(date)) |>
          mutate(year = lubridate::year(date),
                 doy  = lubridate::yday(date)) |>
          rename(value_mean = variable_mean) |>
          select(geography_set, polygon_id, variable, date, year, doy,
                 value_mean, sum_w, sum_wx, sum_wxx, n_valid_pixels)

        # Defensive schema check: every column must be an atomic vector so
        # readr::write_csv() can serialize it. If anything became a matrix
        # or list column, fail loudly here rather than with the cryptic
        # 'invalid columns at index(s): N' from cli.
        bad <- vapply(daily_for_csv,
                      function(col) is.list(col) || !is.null(dim(col)),
                      logical(1L))
        if (any(bad)) {
          stop(sprintf(
            "[summary] daily_for_csv has non-atomic columns: %s (geography_set=%s variable=%s year=%d)",
            paste(names(daily_for_csv)[bad], collapse = ", "),
            set_name, vbl, yr))
        }

        daily_rows[[length(daily_rows) + 1L]] <- daily_for_csv

        comp_df <- tryCatch(
          composite_to_8day(daily_df, config = config),
          error = function(e) {
            warning(sprintf("[summary] composite FAILED %s/%s/%d: %s",
                            set_name, vbl, yr, conditionMessage(e)))
            NULL
          }
        )

        if (!is.null(comp_df) && nrow(comp_df) > 0L) {
          summary_rows[[length(summary_rows) + 1L]] <- comp_df
        }
      }
    }
  }

  out_summary <- if (length(summary_rows) > 0L) dplyr::bind_rows(summary_rows)
                 else data.frame()
  out_daily   <- if (length(daily_rows) > 0L)   dplyr::bind_rows(daily_rows)
                 else data.frame()

  if (write) {
    if (!dir.exists(dirname(out_csv))) {
      dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
    }
    readr::write_csv(out_summary, out_csv)
    message(sprintf("[summary] wrote %d rows to %s",
                    nrow(out_summary), out_csv))

    if (!is.null(daily_csv)) {
      if (!dir.exists(dirname(daily_csv))) {
        dir.create(dirname(daily_csv), recursive = TRUE, showWarnings = FALSE)
      }
      readr::write_csv(out_daily, daily_csv)
      message(sprintf("[summary] wrote %d rows to %s",
                      nrow(out_daily), daily_csv))
    }
  }

  invisible(list(summary = out_summary, daily = out_daily))
}
