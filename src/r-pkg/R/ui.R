# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Shiny UI functions

panel_1_load <- layout_sidebar(
  sidebar = sidebar(
    helpText("Load the topgraphy and saved parameters (if any) for the specified camera."),
    open = "always",
    numericInput("roundshot_id", "Roundshot Camera ID", value = 1148),
    actionButton("load", "Load"),
  )
)

panel_2_fit <- layout_sidebar(
  sidebar = sidebar(
    helpText("Fit the coordinate maps for every camera view."),
    open = "always",

    # shrink the buttons to make the rows fit
    tags$style(".sidebar .btn { padding: 0.15rem 0.4rem; font-size: 0.8rem; }"),
    width = "300px",

    # decrease vertical spacing
    tags$style(".sidebar div, .sidebar p { margin-top: -1rem; }"),

    # Camera view ----------

    sliderInput("view", NULL, 1, 1, 1, step = 1),

    # Rotation ------------------

    p("Azimuth:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("azimuth_m10", "-10"),
      actionButton("azimuth_m1", "-1"),
      actionButton("azimuth_m01", "-0.1"),
      actionButton("azimuth_p01", "+0.1"),
      actionButton("azimuth_p1", "+1"),
      actionButton("azimuth_p10", "+10"),
    ),

    p("Elevation:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("elevation_m1", "-1"),
      actionButton("elevation_m01", "-0.1"),
      actionButton("elevation_m001", "-0.01"),
      actionButton("elevation_p001", "+0.01"),
      actionButton("elevation_p01", "+0.1"),
      actionButton("elevation_p1", "+1"),
    ),

    p("Twist:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("twist_m1", "-1"),
      actionButton("twist_m01", "-0.1"),
      actionButton("twist_m001", "-0.01"),
      actionButton("twist_p001", "+0.01"),
      actionButton("twist_p01", "+0.1"),
      actionButton("twist_p1", "+1"),
    ),

    # Shift --------------------

    p("Left - Right:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("right_m1", "-1"),
      actionButton("right_m01", "-0.1"),
      actionButton("right_p01", "+0.1"),
      actionButton("right_p1", "+1"),
    ),

    p("Backward - Forward:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("forward_m1", "-1"),
      actionButton("forward_m01", "-0.1"),
      actionButton("forward_p01", "+0.1"),
      actionButton("forward_p1", "+1"),
    ),

    p("Down - Up:"),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("up_m1", "-1"),
      actionButton("up_m01", "-0.1"),
      actionButton("up_p01", "+0.1"),
      actionButton("up_p1", "+1"),
    ),

    actionButton("reset", "Reset shift"),

    # Field of view ------------------------

    p("FOV:", textOutput("fov", inline = TRUE) ),
    div(
      style = "display: flex; gap: 0.25rem;",
      actionButton("fov_m1", "-1"),
      actionButton("fov_m01", "-0.1"),
      actionButton("fov_p01", "+0.1"),
      actionButton("fov_p1", "+1")
    ),

    # Distortion ------------------------

    p("Distortion:"),
    textInput("distortion_k1", "k1", value = 0),
    textInput("distortion_k2", "k2", value = 0),
    textInput("distortion_k3", "k3", value = 0),

    # Depth ---------------------

    p("Maximum Depth: 10^x"),
    sliderInput("depth_max_exp", NULL, min = 0, max = 5, value = 5, step = 0.1),

    # Opacity ---------------------

    p("Opacity:"),
    sliderInput("opacity", NULL, min = 0, max = 1, value = 1)
  ),

  div(
    style = glue(
      "position: relative; width: {config$canvas$width}px; height: {config$canvas$height}px;"
    ),
    imageOutput(
      "refimage",
    ),
    tags$canvas(
      id = "webgl",
      width = config$canvas$width,
      height = config$canvas$heigh,
      style = glue("position: absolute; top: 0; left: 0; width: {config$canvas$width}px; height: {config$canvas$height}px;"),
      "Please use a browser that supports 'canvas'."
    )
  ),

  textOutput("eye_lv95"),

  tags$script(type = "module", src = "js/dsm.js"),
  tags$script(type = "module", src = "js/render.js"),
)

panel_3_save <- layout_sidebar(
  sidebar = sidebar(
    helpText("Save all coordinate maps and camera parameters."),
    open = "always",
    actionButton("save", "Save"),
  ),
)

ui <- page_navbar(
  title = "Generate Coordinate Maps:",
  id = "navbar",
  nav_panel(
    "1. Load",
    panel_1_load
  ),
  nav_panel(
    "2. Fit",
    panel_2_fit
  ),
  nav_panel(
    "3. Save",
    panel_3_save
  )
)
