// Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
// Distributed under the terms of the BSD 3-Clause License.
// SPDX-License-Identifier: BSD-3-Clause

// Load vertices and indices arrays from parquet files

import { parquetRead } from "https://esm.sh/hyparquet";

Shiny.addCustomMessageHandler("loadVerticesIndices", loadVerticesIndices);

async function parquetReadPath(path) {
  const response = await fetch(path);
  const arrayBuffer = await response.arrayBuffer();
  return new Promise((resolve) => {
    parquetRead({ file: arrayBuffer, onComplete: resolve });
  });
}

async function loadVerticesIndices(roundshot_id) {

  // arrays of row-arrays from hyparquet
  const verticesData = await parquetReadPath(`vertices_indices/${roundshot_id}_vertices.parquet`);
  const indicesData = await parquetReadPath(`vertices_indices/${roundshot_id}_indices.parquet`);

  // Flatten vertices: each row is expected to be the [x, y, z] coordinates of the vertex
  const vertices = new Float32Array(verticesData.flat());

  // Flatten indices: each row is expected to be the [i0, i1, i2] vertex indices of the triangle
  const indices = new Uint32Array(indicesData.flat());

  // Make available globally and notify render.js
  window._dsmGeometry = { vertices, indices };
  window.dispatchEvent(new CustomEvent("dsmGeometryLoaded", {
    detail: { vertices, indices }
  }));
}
