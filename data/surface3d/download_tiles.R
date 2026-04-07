# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Download the tiles of the SwissSurface3D DSM raster from a .csv
# of URLs, which was generated using
# https://www.swisstopo.admin.ch/en/height-model-swisssurface3d-raster

# %%

library(cli)
library(readr)

urls_csv <- "data/surface3d/ch.swisstopo.swisssurface3d-raster-oGXMXjVp.csv"
urls <- read_csv(urls_csv)

cli_progress_bar("Downloading tiles", total = nrow(urls))
for (row in seq_len(nrow(urls))) {
  url <- urls[[row, 1]]

  # Extract filename from URL
  filename <- basename(url)
  destfile <- file.path("data/surface3d/tiles", filename)

  tryCatch({
      download.file(url, destfile, mode = "wb", quiet = TRUE)
    },
    error = function(e) {
      cat("Error downloading:", url, "\n   Message:", e$message, "\n")
    }
  )

  cli_progress_update()
}

cli_progress_done()
