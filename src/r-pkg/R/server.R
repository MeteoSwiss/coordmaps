# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Shiny server function

server <- function(input, output, session) {

  addResourcePath("vertices_indices", "data/vertices_indices")
  addResourcePath("js", "src/js")

  eye_init <- NULL  # initial camera position
  eye <- reactiveVal()  # rendering position vector
  RFU <- reactiveVal()  # right-forward-up orientation matrix
  fov <- reactiveVal()  # field of view

  eyes <- NULL  # per-view eye
  RFUs <- NULL  # per-view RFU

  observeEvent(input$load, {
    # Read camera location in LV95 coordinates from metadata table ---------

    location <- readxl::read_excel("data/camera_metadata.xlsx") |>
      filter(.data$Roundshot_ID == input$roundshot_id) |>
      select(
        lv95_e = "LV95_E",
        lv95_n = "LV95_N",
        base_hasl = "Base_HASL",
        height_ag = "Height_AG",
        views = "Analysis_Views"
      )
    location_2d_lv95 <- st_sfc(
      st_point(c(location$lv95_e, location$lv95_n)),
      crs = 2056
    )
    elevation <- location$base_hasl + location$height_ag

    session$sendCustomMessage("loadVerticesIndices", input$roundshot_id)

    cam_parameters_path = file.path("data", "cam_parameters", paste0(input$roundshot_id, ".rds"))
    if (file.exists(cam_parameters_path)) {

      e <- new.env()
      load(cam_parameters_path, e)

      eyes <<- e$eyes
      RFUs <<- e$RFUs
      e$fov |> fov()

      eyes[[1]] |> eye()
      RFUs[[1]] |> RFU()

      eye_init <<- eye()

      updateTextInput(session, "distortion_k1", value = e$distortion_k1)
      updateTextInput(session, "distortion_k2", value = e$distortion_k2)
      updateTextInput(session, "distortion_k3", value = e$distortion_k3)

      updateSliderInput(session, "depth_max_exp", value = e$depth_max_exp)

    } else {

      eyes <<- vector("list", location$views)
      RFUs <<- vector("list", location$views)

      # Compute eye and RFU in ECEF coordinates -------------

      location_3d_lv95 <- st_sfc(
        st_point(c(st_coordinates(location_2d_lv95), elevation)),
        crs = 2056
      )
      forward_step_lv95 <- st_sfc(
        st_point(st_coordinates(location_3d_lv95) + c(0, 1, 0)),
        crs = 2056
      )
      up_step_lv95 <- st_sfc(
        st_point(st_coordinates(location_3d_lv95) + c(0, 0, 1)),
        crs = 2056
      )

      location_3d_ecef = st_transform(location_3d_lv95, 4978)  # earth-centered, earth-fixed Cartesian CRS
      forward_step_ecef = st_transform(forward_step_lv95, 4978)
      up_step_ecef = st_transform(up_step_lv95, 4978)

      st_coordinates(location_3d_ecef) |> as.vector() |> eye()
      eye_init <<- eye()

      forward <- as.vector(
        st_coordinates(forward_step_ecef) - st_coordinates(location_3d_ecef)
      )
      up <- as.vector(
        st_coordinates(up_step_ecef) - st_coordinates(location_3d_ecef)
      )
      right <- as.vector(cross_product(forward, up))

      matrix(c(right, forward, up), 3) |>
        gramschmidt() |>
        RFU()

      config$fov_default |> fov()
    }

    updateNavbarPage(session, "navbar", selected = "2. Fit")
    if (length(eyes) > 1)
      updateSliderInput(session, "view", max = location$views)
  })

  # View selector -------------------

  observeEvent(input$view, {
    if (!is.null(eyes) && !is.null(eyes[[input$view]])) {
      eyes[[input$view]] |> eye()
      RFUs[[input$view]] |> RFU()
    }
  })

  # Rotation ------------------

  observeEvent(input$azimuth_m10, {
    rotate(RFU(), RFU()[ , 3], -10) |> RFU()
  })
  observeEvent(input$azimuth_m1, {
    rotate(RFU(), RFU()[ , 3], -1) |> RFU()
  })
  observeEvent(input$azimuth_m01, {
    rotate(RFU(), RFU()[ , 3], -0.1) |> RFU()
  })
  observeEvent(input$azimuth_p10, {
    rotate(RFU(), RFU()[ , 3], 10) |> RFU()
  })
  observeEvent(input$azimuth_p1, {
    rotate(RFU(), RFU()[ , 3], 1) |> RFU()
  })
  observeEvent(input$azimuth_p01, {
    rotate(RFU(), RFU()[ , 3], 0.1) |> RFU()
  })

  observeEvent(input$elevation_m1, {
    rotate(RFU(), RFU()[ , 1], -1) |> RFU()
  })
  observeEvent(input$elevation_m01, {
    rotate(RFU(), RFU()[ , 1], -0.1) |> RFU()
  })
  observeEvent(input$elevation_m001, {
    rotate(RFU(), RFU()[ , 1], -0.01) |> RFU()
  })
  observeEvent(input$elevation_p1, {
    rotate(RFU(), RFU()[ , 1], 1) |> RFU()
  })
  observeEvent(input$elevation_p01, {
    rotate(RFU(), RFU()[ , 1], 0.1) |> RFU()
  })
  observeEvent(input$elevation_p001, {
    rotate(RFU(), RFU()[ , 1], 0.01) |> RFU()
  })

  observeEvent(input$twist_m1, {
    rotate(RFU(), RFU()[ , 2], -1) |> RFU()
  })
  observeEvent(input$twist_m01, {
    rotate(RFU(), RFU()[ , 2], -0.1) |> RFU()
  })
  observeEvent(input$twist_m001, {
    rotate(RFU(), RFU()[ , 2], -0.01) |> RFU()
  })
  observeEvent(input$twist_p1, {
    rotate(RFU(), RFU()[ , 2], 1) |> RFU()
  })
  observeEvent(input$twist_p01, {
    rotate(RFU(), RFU()[ , 2], 0.1) |> RFU()
  })
  observeEvent(input$twist_p001, {
    rotate(RFU(), RFU()[ , 2], 0.01) |> RFU()
  })


  # Shift ----------------

  observeEvent(input$right_m1, {
    { eye() - RFU()[ , 1] } |> eye()
  })
  observeEvent(input$right_m01, {
    { eye() - 0.1 * RFU()[ , 1] } |> eye()
  })
  observeEvent(input$right_p1, {
    { eye() + RFU()[ , 1] } |> eye()
  })
  observeEvent(input$right_p01, {
    { eye() + 0.1*RFU()[ , 1] } |> eye()
  })

  observeEvent(input$forward_p1, {
    { eye() + RFU()[ , 2] } |> eye()
  })
  observeEvent(input$forward_p01, {
    { eye() + 0.1*RFU()[ , 2] } |> eye()
  })
  observeEvent(input$forward_m1, {
    { eye() - RFU()[ , 2] } |> eye()
  })
  observeEvent(input$forward_m01, {
    { eye() - 0.1*RFU()[ , 2] } |> eye()
  })

  observeEvent(input$up_p1, {
    { eye() + RFU()[ , 3] } |> eye()
  })
  observeEvent(input$up_p01, {
    { eye() + 0.1 * RFU()[ , 3] } |> eye()
  })
  observeEvent(input$up_m1, {
    { eye() - RFU()[ , 3] } |> eye()
  })
  observeEvent(input$up_m01, {
    { eye() - 0.1 * RFU()[ , 3] } |> eye()
  })

  observeEvent(input$reset, {
    eye_init |> eye()
  })

  # FOV -----------------

  observeEvent(input$fov_m1, {
    { fov() - 1 } |> fov()
  })
  observeEvent(input$fov_m01, {
    { fov() - 0.1 } |> fov()
  })
  observeEvent(input$fov_p01, {
    { fov() + 0.1 } |> fov()
  })
  observeEvent(input$fov_p1, {
    { fov() + 1 } |> fov()
  })

  # Opacity -------------

  observe({
    req(!is.null(input$opacity))
    session$sendCustomMessage("setOpacity", input$opacity)
  })

  # Output -------------------

  output$refimage <- renderImage({
    req(input$roundshot_id, input$view)
    refimage_path <- list.files(
      path = file.path("data", "refimage", input$roundshot_id),
      pattern = paste0(input$roundshot_id, "_", input$view, "_.*\\.jpe?g$"),
      full.names = TRUE
    )
    return(list(
      src = refimage_path,
      width = config$canvas$width,
      height = config$canvas$height
    ))
  }, deleteFile = FALSE
  )

  observe({
    req(
      input$view,
      eye(),
      RFU(),
      fov(),
      input$depth_max_exp,
      input$distortion_k1,
      input$distortion_k2,
      input$distortion_k3
    )

    eyes[[input$view]] <<- eye()
    RFUs[[input$view]] <<- RFU()

    session$sendCustomMessage(
      "render",
      list(
        eyeInit = eye_init,
        eye = eye(),
        RFU = as.vector(RFU()),
        fov = fov(),
        depthMax = 10^input$depth_max_exp,
        distortionCoefficients = c(
          input$distortion_k1,
          input$distortion_k2,
          input$distortion_k3
        )
      )
    )
  })

  output$fov <- renderText({
    fov()
  })

  output$eye_lv95 <- renderText({
    eye_lv95 <- st_sfc(st_point(eye()), crs = 4978) |> st_transform(2056) |>
      st_coordinates() |> round(digits=1)
    paste("Eye position (LV95):", eye_lv95[1], "E,", eye_lv95[2], "N,", eye_lv95[3], "m ASL")
  })

  # Saving of coordinate maps and camera parameters --------------------

  observeEvent(input$save, {

    for (view in seq_len(length(eyes))) {
      showNotification(
        id = "save_notification",
        ui = paste("Saving view", view, "..."),
        duration = 2
      )
      session$sendCustomMessage(
        "offscreenRender",
        list(
          view = view,
          eyeInit = eye_init,
          eye = eyes[[view]],
          RFU = as.vector(RFUs[[view]]),
          fov = fov(),
          depthMax = 10^input$depth_max_exp,
          distortionCoefficients = c(
            input$distortion_k1,
            input$distortion_k2,
            input$distortion_k3
          )
        )
      )
    }

    cam_parameters_dir <- file.path("data", "cam_parameters")
    dir.create(cam_parameters_dir, recursive = TRUE, showWarnings = FALSE)
    cam_parameters_path <- file.path(cam_parameters_dir, paste0(input$roundshot_id, ".rds"))
    fov <- fov()
    distortion_k1 <- input$distortion_k1
    distortion_k2 <- input$distortion_k2
    distortion_k3 <- input$distortion_k3
    depth_max_exp <- input$depth_max_exp
    save(eyes, RFUs, fov, distortion_k1, distortion_k2, distortion_k3, depth_max_exp, file = cam_parameters_path)

    showNotification("Done.", duration = 2)
  })

  observeEvent(input$save_fbo, {
    coordmap_dir <- file.path("data", "coordmap", input$roundshot_id)
    dir.create(coordmap_dir, recursive = TRUE, showWarnings = FALSE)

    raw_bytes <- base64enc::base64decode(input$save_fbo$bytes)
    pixels_vec <- readBin(
      raw_bytes,
      what = "double",
      size = 4,
      n = length(raw_bytes) / 4,
      endian = "little"
    )
    pixels_array <- array(
      pixels_vec,
      dim = c(4, config$canvas$width, config$canvas$height)
    )
    coordmaps <- aperm(pixels_array, c(3, 2, 1))  # (height, width, XYZD)
    RcppCNPy::npySave(file.path(coordmap_dir, paste0(input$roundshot_id, "_", input$save_fbo$view, ".npy")), coordmaps)

    depthmap <- coordmaps[ , , 4]
    depthmap_path <- file.path(coordmap_dir, paste0(input$roundshot_id, "_", input$save_fbo$view, "_depthmap.png"))
    png(depthmap_path, width = config$canvas$width, height = config$canvas$height)
    par(mar = c(0, 0, 0, 0))
    image(t(depthmap), useRaster = TRUE, axes = FALSE, col = grey.colors(256, start = 0, end = 1))
    dev.off()

    Sys.sleep(2)  # necessary to keep Shiny <-> browser communication in sync
  })
}
