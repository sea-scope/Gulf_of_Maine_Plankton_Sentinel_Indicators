## export_viewer_metadata.R
## Step 5 of the DFO Calanus biomass workflow.
## Generates plots/stations_metadata.json from the biomass summary CSV.
## Each entry records the filename prefix used in per-year PNGs, a display
## label, the data source type, and the year range available.
##
## Input:  summaries/DFO_biomass_summary.csv
## Output: plots/stations_metadata.json
##
## Required packages: jsonlite

library(jsonlite)

work_dir <- getwd()

# ── Read summary ──────────────────────────────────────────────────────────
summary_file <- file.path(work_dir, "summaries", "DFO_biomass_summary.csv")
df <- read.csv(summary_file, stringsAsFactors = FALSE)

# ── CINAR mapping (must match DFO_biomass_visualization_CINAR.R) ──────────
cinar_info <- data.frame(
  key          = c("WSS", "EGOM", "JB", "Browns", "Halifax",
                   "GeorgesNEC", "GMB150", "BOF", "SBNMS"),
  display_name = c("Western Scotian Shelf", "Eastern Gulf of Maine",
                   "Jordan Basin", "Browns Bank", "Eastern Scotian Shelf",
                   "Georges Basin and NE Channel", "Grand Manan Basin",
                   "Bay of Fundy", "Stellwagen Bank NMS"),
  file_name    = c("WesternScotianShelf", "EasternGOM",
                   "JordanBasin", "BrownsBank", "EasternScotianShelf",
                   "GeorgesNEC", "GrandManan", "BayOfFundy", "SBNMS"),
  stringsAsFactors = FALSE
)

# ── Build CINAR entries ───────────────────────────────────────────────────
cinar_df <- df[!startsWith(df$polygon, "ecomon"), ]

cinar_entries <- lapply(seq_len(nrow(cinar_info)), function(i) {
  rows <- cinar_df[cinar_df$polygon == cinar_info$key[i], ]
  if (nrow(rows) == 0) return(NULL)
  list(
    id       = paste0("CINAR_", cinar_info$file_name[i]),
    label    = cinar_info$display_name[i],
    type     = "CINAR",
    min_year = min(rows$fYear),
    max_year = max(rows$fYear)
  )
})
cinar_entries <- Filter(Negate(is.null), cinar_entries)

# ── Build EcoMon entries ──────────────────────────────────────────────────
ecomon_df <- df[startsWith(df$polygon, "ecomon"), ]
ecomon_df$stratum_id <- as.integer(sub("ecomon_", "", ecomon_df$polygon))

strata_ids <- sort(unique(ecomon_df$stratum_id))

ecomon_entries <- lapply(strata_ids, function(sid) {
  rows <- ecomon_df[ecomon_df$stratum_id == sid, ]
  list(
    id       = paste0("EcoMon_", sid),
    label    = paste("EcoMon Stratum", sid),
    type     = "EcoMon",
    min_year = min(rows$fYear),
    max_year = max(rows$fYear)
  )
})

# ── Combine and write JSON ────────────────────────────────────────────────
all_entries <- c(cinar_entries, ecomon_entries)

output_dir <- file.path(work_dir, "plots")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, "stations_metadata.json")
writeLines(toJSON(all_entries, pretty = TRUE, auto_unbox = TRUE), output_file)

cat(sprintf("Wrote %d entries to %s\n", length(all_entries), output_file))
