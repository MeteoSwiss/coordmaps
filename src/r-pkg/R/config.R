# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# App configuration

config <- list()

config$canvas <- list()
config$canvas$width <- 1550  # pixel width of canvas and offscreen buffers
config$canvas$height <- 1035  # pixel height of canvas and offscreen buffers

config$lod <- list()  # level of detail
config$lod$resolving_depth <- 100  # depth in meters at which the base resolution is resolved by a pixel
config$lod$base_resolution <- 0.5  # base resolution of surface3d DSM in meters
config$lod$levels <- 11  # desired levels of detail

config$fov_default <- 46  # default vertical field of view
