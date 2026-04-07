# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Generate arrays of vertices and indices from s3d_eu_mosaic raster

# %%

devtools::load_all("src/r-pkg")

generate_vertices_indices(1157)
