# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Generate mosaic of tiles at specified resolution

# %%

library(cli)
library(ggplot2)
library(stars)

resolution <- 32  # meters

# %% ----------------------------

tile_paths <- list.files(
  path = "data/surface3d/tiles",
  pattern = glob2rx("swisssurface3d-raster_*.tif"),
  full.names = TRUE
) |>
  sort(decreasing = FALSE)  # will overwrite mosaic with more recent versions of tiles

tiles <- list()
cli_progress_bar("Load all tiles and downsample each to target resolution", total = length(tile_paths))
for (tt in seq_along(tile_paths)) {
  tile <- read_stars(tile_paths[[tt]], proxy = FALSE)
  target <- st_as_stars(st_bbox(tile), dx = resolution)
  downsampled <- st_warp(tile, target)
  tiles[[tt]] <- downsampled
  cli_progress_update()
}
cli_progress_done()

mosaic <- do.call(st_mosaic, tiles)
write_stars(mosaic, paste0("data/surface3d/mosaic/", resolution, ".tif"))

# ggplot() +
#   geom_stars(data = mosaic) +
#   coord_equal() +
#   scale_fill_viridis_c(na.value = NA) +
#   labs(fill = "Elevation (m)")

# %% ----------------------------

resolution <- 2 * resolution

target <- st_as_stars(st_bbox(mosaic), dx = resolution)
downsampled <- st_warp(mosaic, target)

ggplot() +
  geom_stars(data = downsampled) +
  coord_equal() +
  scale_fill_viridis_c(na.value = NA) +
  labs(fill = "Elevation (m)")

write_stars(downsampled, paste0("data/surface3d/mosaic/", resolution, ".tif"))
