## DFO_region_map.R
## Publication-quality region maps for the DFO Calanus biomass project.
## Three versions: (1) CINAR publication, (2) SBNMS / GoM publication, (3) interactive stub.
##
## Follows the approach of PT_track_presentation_map.R:
##   - ggplot2 with fortify.bathy() for bathymetry contours
##   - mapdata::map_data("world2Hires") coastline drawn ON TOP for clean land masking
##   - Pre-clipped poly_*.csv polygon boundaries (NaN-row aware)
##
## Station symbol types (applied to both maps):
##   circle   (21) — MBON time series     (WBTS, CMTS)
##   square   (22) — MWRA time series     (F22, F29)       [color = magenta]
##   triangle (24) — NERACOOS Buoys       (A01, B01, E01, I01, M01, NEC BuoyN)
##   diamond  (23) — DFO time series      (Prince5, H2)

library(ggplot2)
library(mapdata)
library(marmap)
library(dplyr)

# Repository root — open SPM_calanus_biomass.Rproj before sourcing.
work_dir   <- getwd()
output_dir <- file.path(work_dir, "figures")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# ============================================================
# HELPER: load a poly_*.csv (no header; NaN rows separate sub-polygons)
# ============================================================
load_poly <- function(name) {
  f <- file.path(work_dir, "data", paste0("poly_", name, ".csv"))
  if (!file.exists(f)) { warning(paste("poly CSV not found:", f)); return(NULL) }
  df <- read.csv(f, header = FALSE, col.names = c("lon", "lat"))
  nan_rows <- which(is.nan(df$lon) | is.nan(df$lat))
  if (length(nan_rows) > 0) {
    df$group <- NA_integer_
    g <- 1L; start <- 1L
    for (nr in nan_rows) {
      if (nr > start) df$group[start:(nr - 1)] <- g
      g <- g + 1L; start <- nr + 1L
    }
    if (start <= nrow(df)) df$group[start:nrow(df)] <- g
    df <- df[!is.na(df$group), ]
  } else {
    df$group <- 1L
  }
  df
}

# ============================================================
# POLYGON BOUNDARIES
# ============================================================
poly_WSS     <- load_poly("WSS_broad")
poly_EGOM    <- load_poly("EGOM_broad")
poly_JB      <- load_poly("JB_deep")
poly_Browns  <- load_poly("Browns_line")
poly_Halifax <- load_poly("Halifax_line")
poly_GBNEC   <- load_poly("GeorgesNEC")
poly_GMB150  <- load_poly("GMB_150")
poly_BOF     <- load_poly("BOF_latlon")

# SBNMS boundaries (no header: lon, lat)
sbnms_bnd  <- read.csv(file.path(work_dir, "data", "SBNMS.csv"),
                        header = FALSE, col.names = c("lon", "lat"))
sbnms_40m  <- read.csv(file.path(work_dir, "data", "SBNMS_40m_latlon.csv"),
                        header = FALSE, col.names = c("lon", "lat"))

# ============================================================
# FIXED STATIONS AND TRANSECTS
# Coordinates updated from pipeline doc (NDBC official positions).
# ============================================================
stations <- data.frame(
  name = c("WBTS",             "CMTS",
           "F22",              "F29",
           "A01",     "B01",   "E01",    "I01",    "M01",
           "Prince5", "NEC BuoyN", "H2"),
  lon  = c(-69.8616,  -69.50383,
           -70.6177,  -70.29,
           -70.566,   -70.426,  -69.355,  -68.112,  -67.876,
           -66.8500,  -65.909,  -63.3167),
  lat  = c( 42.8627,   43.7495,
             42.4798,   42.1167,
             42.523,    43.179,   43.715,   44.103,   43.497,
             44.9300,   42.325,   44.2667),
  type = c("MBON time series", "MBON time series",
           "MWRA time series", "MWRA time series",
           "NERACOOS Buoys",   "NERACOOS Buoys", "NERACOOS Buoys",
           "NERACOOS Buoys",   "NERACOOS Buoys",
           "DFO time series",  "NERACOOS Buoys", "DFO time series"),
  stringsAsFactors = FALSE
)

# Browns Bank Line transect
bbl <- data.frame(
  lon = c(-65.48, -65.48, -65.4833, -65.4833, -65.50, -65.51),
  lat = c( 43.25,  43.00,  42.76,    42.45,   42.1333, 42.00)
)

# ============================================================
# ECOMON STRATA — loaded for SBNMS map (strata 35, 36, 37, 40)
# ============================================================
strata_coords    <- read.csv(file.path(work_dir, "data", "EMstrata_v4_coords.csv"))
sbnms_strata_ids <- c(35L, 36L, 37L, 40L)
sbnms_strata     <- strata_coords[strata_coords$stratum_id %in% sbnms_strata_ids, ]
sbnms_strata$label <- paste("Stratum", sbnms_strata$stratum_id)

strata_pal_sbnms <- c(
  "Stratum 35" = "#4E79A7",   # blue
  "Stratum 36" = "#F28E2B",   # orange
  "Stratum 37" = "#59A14F",   # green
  "Stratum 40" = "#E15759"    # red
)

# ============================================================
# BATHYMETRY — cached as gom_bathy.rda
# ============================================================
bathy_cache <- file.path(work_dir, "cache", "gom_bathy.rda")
if (file.exists(bathy_cache)) {
  cat("Loading cached bathymetry...\n")
  load(bathy_cache)   # loads 'gom'
} else {
  cat("Downloading bathymetry (first run only)...\n")
  gom <- getNOAA.bathy(lon1 = -77, lon2 = -58, lat1 = 39, lat2 = 48, resolution = 1)
  save(gom, file = bathy_cache)
  cat("Saved to", bathy_cache, "\n")
}
bf <- fortify.bathy(gom)

# ============================================================
# COASTLINE (land drawn ON TOP for clean masking)
# ============================================================
reg <- map_data("world2Hires")
reg <- subset(reg, region %in% c("Canada", "USA"))
reg$long <- (360 - reg$long) * -1   # convert world2Hires 0-360 to standard W lon

# ============================================================
# SHARED COLOR SCHEMES
# ============================================================
region_pal <- c(
  "Western Scotian Shelf"            = "#7FB069",  # muted green
  "Eastern Gulf of Maine"            = "#E8A838",  # amber
  "Jordan Basin"                     = "#8B8BAE",  # slate
  "Browns Bank"                      = "#C9A96E",  # tan
  "Eastern Scotian Shelf"            = "#C47C5A",  # terracotta
  "Georges Basin and NE Channel"     = "#5B9E8A",  # teal
  "Grand Manan Basin"                = "#B05E6C",  # rose
  "Bay of Fundy"                     = "#D4A5C9"   # lavender
)

# name = NULL in scale_shape_manual removes the "Station type" legend subtitle
station_shapes <- c("NERACOOS Buoys"   = 24,   # filled up-triangle
                    "MBON time series"  = 21,   # filled circle
                    "MWRA time series"  = 22,   # filled square
                    "DFO time series"   = 23)   # filled diamond
station_fills  <- c("NERACOOS Buoys"   = "white",
                    "MBON time series"  = "gold",
                    "MWRA time series"  = "magenta",
                    "DFO time series"   = "tomato")

# ============================================================
# SHARED THEME
# ============================================================
map_theme <- theme_bw(base_size = 16) +
  theme(
    axis.title        = element_blank(),
    legend.background = element_rect(fill = alpha("white", 0.85), color = NA),
    legend.key.size   = unit(0.5, "cm"),
    legend.spacing.y  = unit(0.1, "cm"),
    panel.grid        = element_line(color = "grey90", linewidth = 0.2)
  )

# ============================================================
# VERSION 1: CINAR PUBLICATION MAP
# xlim -72 to -60. Shows only NERACOOS Buoys and DFO time series stations;
# MBON, MWRA, and buoys A01/B01 excluded for a cleaner map.
# ============================================================
cat("\nBuilding Version 1: CINAR publication map...\n")

# CINAR map: exclude MBON / MWRA types and A01, B01
stations_cinar <- stations %>%
  filter(!type %in% c("MBON time series", "MWRA time series")) %>%
  filter(!name %in% c("A01", "B01"))

# Combined fill scale: polygon colors (shown in legend) + station fills (hidden)
cinar_fill_values <- c(region_pal, station_fills)

p_cinar <- ggplot() +

  # Bathymetry contours (200 m, 100 m, 50 m)
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -200, linewidth = 0.4, colour = "grey55") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -100, linewidth = 0.25, colour = "grey65") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -50,  linewidth = 0.15, colour = "grey75") +

  # CINAR region polygons (semi-transparent fills)
  geom_polygon(data = poly_WSS,    aes(x = lon, y = lat, group = group,
               fill = "Western Scotian Shelf"),        color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_EGOM,   aes(x = lon, y = lat, group = group,
               fill = "Eastern Gulf of Maine"),         color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_JB,     aes(x = lon, y = lat, group = group,
               fill = "Jordan Basin"),                  color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_Browns, aes(x = lon, y = lat, group = group,
               fill = "Browns Bank"),                   color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_Halifax,aes(x = lon, y = lat, group = group,
               fill = "Eastern Scotian Shelf"),         color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_GBNEC,  aes(x = lon, y = lat, group = group,
               fill = "Georges Basin and NE Channel"),  color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_GMB150, aes(x = lon, y = lat, group = group,
               fill = "Grand Manan Basin"),             color = "grey30", linewidth = 0.4, alpha = 0.55) +
  geom_polygon(data = poly_BOF,    aes(x = lon, y = lat, group = group,
               fill = "Bay of Fundy"),                  color = "grey30", linewidth = 0.4, alpha = 0.55) +

  # Unified fill scale: polygon colors in legend; station fills mapped but hidden
  scale_fill_manual(values = cinar_fill_values,
                    breaks = names(region_pal),
                    name   = NULL) +

  # Land ON TOP — masks any polygon bleed onto shore
  geom_polygon(data = reg, aes(x = long, y = lat, group = group),
               fill = "#A89070", color = "grey30", linewidth = 0.35) +

  # Browns Bank Line transect — label shifted west, adjacent to the dashed line
  geom_path(data = bbl, aes(x = lon, y = lat),
            color = "black", linewidth = 1.0, linetype = "dashed") +
  annotate("text", x = -66.0, y = 42.90, label = "Browns\nBank\nLine",
           size = 3, fontface = "italic", hjust = 0, color = "black") +

  # Fixed stations (NERACOOS Buoys + DFO time series only)
  geom_point(data = stations_cinar,
             aes(x = lon, y = lat, shape = type, fill = type),
             size = 3, color = "black", stroke = 0.7) +
  scale_shape_manual(values = station_shapes, name = NULL) +

  # Station labels
  geom_text(data = stations_cinar, aes(x = lon, y = lat, label = name),
            size = 3, vjust = -0.8, fontface = "bold") +

  coord_map(xlim = c(-72, -60), ylim = c(41.5, 46.5)) +

  labs(title = "CINAR Study Regions — Gulf of Maine and Scotian Shelf") +
  map_theme +
  theme(
    legend.position      = c(0.01, 0.99),
    legend.justification = c(0, 1),
    legend.text          = element_text(size = 12),
    legend.key.size      = unit(0.45, "cm"),
    legend.title         = element_blank(),
    legend.spacing.y     = unit(0.05, "cm")
  ) +
  guides(
    fill  = guide_legend(order = 1, override.aes = list(alpha = 0.6, color = "grey30")),
    shape = guide_legend(order = 2),
    color = "none"
  )

ggsave(file.path(output_dir, "DFO_region_map_CINAR.png"),
       plot = p_cinar, width = 14, height = 9, dpi = 300, bg = "white")
cat("Saved: DFO_region_map_CINAR.png\n")

# ============================================================
# VERSION 2: SBNMS / GULF OF MAINE PUBLICATION MAP
# Domain: -72 to -67.75°W, 41–45°N.
# EcoMon strata 35, 36, 37, 40 as color-coded fills.
# CINAR polygon outlines removed; no EGOM/JB dashed context lines.
# Legend: no title, top-left inside figure, smaller font, 2 columns.
# ============================================================
cat("\nBuilding Version 2: SBNMS / GoM publication map...\n")

# All stations within the SBNMS map domain
stations_sbnms <- stations %>%
  filter(lon >= -72 & lon <= -67.75 & lat >= 41 & lat <= 45)

# Combined fill scale: stratum colors (shown) + station fills (hidden)
sbnms_fill_values <- c(strata_pal_sbnms, station_fills)

p_sbnms <- ggplot() +

  # Denser bathymetry contours for shelf-scale detail
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -200, linewidth = 0.5,  colour = "grey50") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -100, linewidth = 0.35, colour = "grey60") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -50,  linewidth = 0.25, colour = "grey70") +
  geom_contour(data = bf, aes(x = x, y = y, z = z),
               breaks = -20,  linewidth = 0.15, colour = "grey80") +

  # EcoMon strata 35, 36, 37, 40 — color-coded filled polygons
  geom_polygon(data = sbnms_strata,
               aes(x = lon, y = lat, group = stratum_id, fill = label),
               color = "grey30", linewidth = 0.5, alpha = 0.5) +

  # Unified fill scale: stratum colors in legend; station fills mapped but hidden
  scale_fill_manual(values = sbnms_fill_values,
                    breaks = names(strata_pal_sbnms),
                    name   = NULL) +

  # SBNMS sanctuary boundary
  geom_polygon(data = sbnms_bnd, aes(x = lon, y = lat),
               fill = NA, color = "#1B5E20", linewidth = 1.2) +

  # SBNMS 40 m isobath
  geom_path(data = sbnms_40m, aes(x = lon, y = lat),
            color = "#4CAF50", linewidth = 0.8, linetype = "dashed") +

  # Land ON TOP
  geom_polygon(data = reg, aes(x = long, y = lat, group = group),
               fill = "#A89070", color = "grey30", linewidth = 0.35) +

  # Browns Bank Line transect + label
  geom_path(data = bbl, aes(x = lon, y = lat),
            color = "black", linewidth = 1.0, linetype = "dashed") +
  annotate("text", x = -66.0, y = 42.4, label = "Browns\nBank\nLine",
           size = 3, fontface = "italic", hjust = 0, color = "black") +

  # Fixed stations
  geom_point(data = stations_sbnms,
             aes(x = lon, y = lat, shape = type, fill = type),
             size = 4, color = "black", stroke = 0.8) +
  scale_shape_manual(values = station_shapes, name = NULL) +

  geom_text(data = stations_sbnms %>% filter(name != "F22"),
            aes(x = lon, y = lat, label = name),
            size = 3.5, vjust = -0.9, fontface = "bold") +
  geom_text(data = stations_sbnms %>% filter(name == "F22"),
            aes(x = lon, y = lat, label = name),
            size = 3.5, vjust = 1.8, hjust = 1.2, fontface = "bold") +

  # Sanctuary label — drawn last so it renders on top of all other layers
  annotate("text", x = -70.3, y = 42.65, label = "Stellwagen Bank\nNMS",
           size = 3.5, fontface = "italic", color = "black") +

  coord_map(xlim = c(-72, -67.75), ylim = c(41, 45)) +

  labs(title = "Gulf of Maine Study Area — EcoMon Strata and SBNMS") +
  map_theme +
  theme(
    legend.position   = c(0.01, 0.99),
    legend.justification = c(0, 1),
    legend.text       = element_text(size = 10),
    legend.key.size   = unit(0.4, "cm"),
    legend.spacing.x  = unit(0.2, "cm"),
    legend.spacing.y  = unit(0.05, "cm")
  ) +
  guides(
    fill  = guide_legend(order = 1, ncol = 1,
                         override.aes = list(alpha = 0.6, color = "grey30")),
    shape = guide_legend(order = 2, ncol = 1),
    color = "none"
  )

ggsave(file.path(output_dir, "DFO_region_map_SBNMS.png"),
       plot = p_sbnms, width = 10, height = 8, dpi = 300, bg = "white")
cat("Saved: DFO_region_map_SBNMS.png\n")

# ============================================================
# VERSION 3: INTERACTIVE WEB MAP (stub — requires leaflet)
# ============================================================
cat("\nVersion 3 (interactive) — stub below, not run automatically.\n")
cat("Requires: install.packages(c('leaflet','leaflet.extras'))\n")

## ---- BEGIN INTERACTIVE STUB (not sourced by pipeline) ----
##
## library(leaflet)
## library(leaflet.extras)
##
## region_colors_hex <- setNames(
##   c("#7FB069","#E8A838","#8B8BAE","#C9A96E","#C47C5A","#5B9E8A","#B05E6C","#D4A5C9"),
##   c("WSS","EGOM","JB","Browns","Halifax","GeorgesNEC","GMB150","BOF")
## )
##
## m <- leaflet() %>%
##   addTiles() %>%
##   setView(lng = -68, lat = 43.5, zoom = 6)
##
## # Add each CINAR polygon
## for (poly_name in names(region_colors_hex)) {
##   poly_df <- get(paste0("poly_", c(WSS="WSS_broad",EGOM="EGOM_broad",JB="JB_deep",
##     Browns="Browns_line",Halifax="Halifax_line",GeorgesNEC="GeorgesNEC",
##     GMB150="GMB_150",BOF="BOF_latlon")[poly_name]))
##   if (!is.null(poly_df)) {
##     m <- m %>% addPolygons(
##       lng = poly_df$lon, lat = poly_df$lat,
##       fillColor = region_colors_hex[poly_name], fillOpacity = 0.4,
##       color = "grey40", weight = 1,
##       label = poly_name
##     )
##   }
## }
##
## # Add stations
## m <- m %>% addCircleMarkers(
##   lng = stations$lon, lat = stations$lat,
##   label = stations$name, radius = 6,
##   color = "black", fillColor = "gold", fillOpacity = 0.9, weight = 1
## )
##
## # Add SBNMS boundary
## m <- m %>% addPolygons(
##   lng = sbnms_bnd$lon, lat = sbnms_bnd$lat,
##   fill = FALSE, color = "#1B5E20", weight = 2, dashArray = "5,5",
##   label = "Stellwagen Bank NMS"
## )
##
## htmlwidgets::saveWidget(m, file.path(output_dir, "DFO_region_map_interactive.html"))
## cat("Saved: DFO_region_map_interactive.html\n")
##
## ---- END INTERACTIVE STUB ----

cat("\nAll region map outputs written to figures/\n")
