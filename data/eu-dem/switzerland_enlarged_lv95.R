# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Crop EU-DEM to an area surrounding Switzerland by 100 km
# The raster is available from https://gisco-services.ec.europa.eu/dem/100k/EU_DEM_mosaic_1000K.ZIP

library(ggplot2)
library(stars)

resolution <- 32  # closest binary power to native resolution

eudem <- read_stars("data/eu-dem/eudem_dem_3035_europe.tif")
surface3d_mosaic <- read_stars("data/surface3d/mosaic/32.tif")

s3d_bbox <- st_bbox(surface3d_mosaic)
enlarged_bbox <- s3d_bbox + c(-100000, -100000, 100000, 100000)

crop_bbox <- enlarged_bbox + c(-10000, -10000, 10000, 10000)
eudem_crop <- st_crop(eudem, st_transform(crop_bbox, st_crs(eudem)))

target <- st_as_stars(enlarged_bbox, dx = resolution)
enlarged_warped <- st_warp(eudem_crop, target, use_gdal = TRUE)

write_stars(enlarged_warped, "data/eu-dem/switzerland_enlarged_lv95.tif")
