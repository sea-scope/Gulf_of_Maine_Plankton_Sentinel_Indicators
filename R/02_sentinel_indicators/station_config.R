# =============================================================================
# Station Configuration for Sentinel Indicators Pipeline
#
# Each station entry defines the parameters needed by the ingest and
# preparation layers. To add a new station, add an entry here — no
# downstream analysis code needs to change.
# =============================================================================

station_config <- list(

  WBTS = list(
    station_id     = "WBTS",
    station_code   = "WB-7",           # Code used in UBER Excel "Station" column
    deep_tow_min   = 240,              # Minimum net depth (m) for deep-tow filter
    season_boundaries = list(
      spring = c(74, 147),             # DOY 74–147
      summer = c(148, 247),            # DOY 148–247
      fall   = c(248, 365),            # DOY 248–365
      winter = c(1, 73)               # DOY 1–73
    ),
    n_seasons      = 4,
    reference_period = c(2004, 2010),  # Baseline years for anomaly calculation
    year_start     = 2004,             # First year of reliable data
    trend_window_years = 5,            # Years for dashboard trend calculation
    mbon_source    = FALSE             # No MBON supplement for WBTS
  ),

  CMTS = list(
    station_id     = "CMTS",
    station_code   = "DMC-2",          # Code used in UBER Excel "Station" column
    deep_tow_min   = NULL,             # No deep-tow filter for CMTS
    season_boundaries = list(
      spring = c(74, 147),             # DOY 74–147
      summer = c(148, 247),            # DOY 148–247
      winter = c(248, 73)              # DOY 248–73 (wraps across year boundary)
    ),
    n_seasons      = 3,
    reference_period = c(2008, 2010),  # Baseline years (n=3, flag in methods)
    year_start     = 2007,             # First year of reliable data
    trend_window_years = 5,            # Years for dashboard trend calculation
    mbon_source    = TRUE,             # Supplement with MBON Zoop Counts
    mbon_station_code = "CMTS"         # Station code in MBON Excel
  )
)
