# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Surround the SwissSurface3D with the EU-DEM mosaic

# %%

library(stars)

resolution <- 32

# %% Surround SwissSurface3d with EU-DEM

surface3d <- read_stars("data/surface3d/mosaic/32.tif")
eudem <- read_stars("data/eu-dem/switzerland_enlarged_lv95.tif")

mosaic <- st_mosaic(surface3d_mosaic, eudem)
write_stars(mosaic, paste0("data/s3d_eu_mosaic/", resolution, ".tif"))

# %% Downsample

resolution <- 2 * resolution

target <- st_as_stars(st_bbox(mosaic), dx = resolution)
downsampled <- st_warp(mosaic, target)

write_stars(downsampled, paste0("data/s3d_eu_mosaic/", resolution, ".tif"))