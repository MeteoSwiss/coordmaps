# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

#' Load all necessary tiles and downsample them to the target resolution
#'
#' @param location_2d_lv95  center location in LV95
#' @param depth  maximum viewing depth in meters
#' @param resolution  target resolution in meters
#'
load_tiles <- function(location_2d_lv95, depth, resolution) {
    E_km <- location_2d_lv95 |> st_coordinates() |> pluck(1)
    N_km <- location_2d_lv95 |> st_coordinates() |> pluck(2)

    E_km_min <- floor((E_km - depth) / 1000)
    E_km_max <- floor((E_km + depth) / 1000)
    N_km_min <- floor((N_km - depth) / 1000)
    N_km_max <- floor((N_km + depth) / 1000)

    tiles <- list()
    tt <- 1
    for (E_km in seq(E_km_min, E_km_max)) {
      for (N_km in seq(N_km_min, N_km_max)) {
        tile_path <- list.files(
          path = "data/surface3d/tiles",
          pattern = glob2rx(paste0(
            "swisssurface3d-raster_*_",
            E_km,
            "-",
            N_km,
            "_0.5_2056_5728.tif"
          )),
          full.names = TRUE
        ) |>
          sort(decreasing = TRUE) |> # most recent version of tile
          pluck(1)

        if (is.null(tile_path))
          next()

        tile <- read_stars(tile_path, proxy = FALSE)
        target <- st_as_stars(st_bbox(tile), dx = resolution)
        downsampled <- st_warp(tile, target)
        tiles[[tt]] <- downsampled
        tt <- tt + 1
      }
    }
    return(tiles)
  }

#' Generate vertices and indices arrays from DSM raster
#'
#' The arrays are saved as parquet files under \code{data/vertices_indices}
#'
#' @param roundshot_id  camera ID
#'
generate_vertices_indices <- function(roundshot_id) {
  location <- readxl::read_excel("data/camera_metadata.xlsx") |>
    filter(.data$Roundshot_ID == roundshot_id) |>
    select(lv95_e = "LV95_E", lv95_n = "LV95_N")

  if (nrow(location) == 0)
    stop("No metadata for roundshot ID ", roundshot_id, ".")

  location_2d_lv95 <- st_sfc(
    st_point(c(location$lv95_e, location$lv95_n)),
    crs = 2056
  )

  # %% ----------------------------------------

  depth <- config$lod$resolving_depth
  resolution <- config$lod$base_resolution
  mosaics <- list()
  for (ll in seq_len(config$lod$levels)) {
    print(paste0("Depth: ", depth, " - Resolution: ", resolution))

    if (resolution <= 16) {
      mosaics[[ll]] <- do.call(
        st_mosaic,
        load_tiles(location_2d_lv95, depth, resolution)
      )
    } else {
      mosaics[[ll]] <- read_stars(paste0(
        "data/s3d_eu_mosaic/",
        resolution,
        ".tif"
      ))
    }

    depth <- depth * 2
    resolution <- resolution * 2
  }

  # %% Create circle/donut crops for all levels of detail ----------------------------------------

  far <- config$lod$resolving_depth
  near <- 0
  crops <- list()
  for (ll in seq_len(config$lod$levels)) {
    print(far)

    outer <- st_buffer(location_2d_lv95, far)
    if (near == 0) {
      crops[[ll]] <- st_crop(mosaics[[ll]], outer)
    } else {
      inner <- st_buffer(location_2d_lv95, near)
      crops[[ll]] <- st_crop(mosaics[[ll]], st_difference(outer, inner))
    }

    p <- ggplot() +
      geom_stars(data = crops[[ll]]) +
      coord_equal() +
      scale_fill_viridis_c(na.value = NA) +
      labs(fill = "Elevation (m)")
    print(p)

    near <- far
    far <- far * 2
  }

  # %% Create vertices and indices of triangulation ----------------------------------------

  vertices_lv95_list <- list()
  for (ll in seq_len(config$lod$levels)) {
    points <- st_as_sf(crops[[ll]], as_points = TRUE, na.rm = TRUE)
    vertices_lv95_list[[ll]] <- cbind(st_coordinates(points), points[[1]])
  }
  vertices_lv95 <- do.call(rbind, vertices_lv95_list)

  indices <- RTriangle::triangulate(RTriangle::pslg(vertices_lv95[, 1:2]))$T # triangulation must happen before the conversion to ECEF (why?)

  # %% Ensure CCW triangle orientation --------------------------------------------------

  cli_progress_bar("Ensure CCW triangle orientation", total = nrow(indices))
  for (i in seq_len(nrow(indices))) {
    triplet <- indices[i, ]
    center <- colMeans(vertices_lv95[triplet, ])
    indices[i, ] <- triplet[order(atan2(
      (vertices_lv95[triplet, 2] - center[2]),
      (vertices_lv95[triplet, 1] - center[1])
    ))]
    cli_progress_update()
  }
  cli_progress_done()

  indices <- indices - 1 # WebGL uses zero-based indexing

  # %% Convert vertices to ECEF ------------------------------

  points_3d_lv95 <- lapply(seq_len(nrow(vertices_lv95)), function(i) {
    st_point(vertices_lv95[i, ])
  }) |>
    st_sfc(crs = 2056)
  points_ecef <- st_transform(points_3d_lv95, 4978)
  vertices_ecef <- st_coordinates(points_ecef)

  # %% Save ----------------------------------------

  arrow::write_parquet(
    vertices_ecef |> as.data.frame(),
    paste0("data/vertices_indices/", roundshot_id, "_vertices.parquet")
  )
  arrow::write_parquet(
    indices |> as.data.frame(),
    paste0("data/vertices_indices/", roundshot_id, "_indices.parquet")
  )
}