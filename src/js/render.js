// Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
// Distributed under the terms of the BSD 3-Clause License.
// SPDX-License-Identifier: BSD-3-Clause

// Render the DSM from the camera's point of view

import * as twgl from "https://twgljs.org/dist/7.x/twgl-full.module.js";

var geometry;  // DSM vertices and indices
window.addEventListener("dsmGeometryLoaded", function (event) {
  geometry = event.detail;
});

var eyeInit;  // initial eye position
var state;  // WebGL state

// --- Display shaders (grayscale depth) ---

var vertexShaderSource = `#version 300 es

in vec4 a_Position;
uniform mat4 u_MvpMatrix;
uniform float u_DepthMax;
out vec4 v_Color;

void main() {
  float intensity;

  gl_Position = u_MvpMatrix * a_Position;

  if (gl_Position.z <= 1.0) {
    intensity = 0.0;
  } else if (gl_Position.z <= u_DepthMax) {
    // intensity = gl_Position.z / u_DepthMax;
    // intensity = sqrt(gl_Position.z) / sqrt(u_DepthMax);
    intensity = pow(gl_Position.z, 1.0/3.0) / pow(u_DepthMax, 1.0/3.0);
    // intensity = log(gl_Position.z) / log(u_DepthMax);
  } else {
    intensity = 1.0;
  }
  v_Color = vec4(intensity, intensity, intensity, 1.0);
}
`;

var fragmentShaderSource = `#version 300 es

precision highp float;

in vec4 v_Color;
out vec4 outColor;

void main() {
  outColor = v_Color;
}
`;

// --- Offscreen shaders (XYZ + depth) ---

var offscreenVertexShaderSource = `#version 300 es

in vec4 a_Position;
uniform mat4 u_MvpMatrix;
uniform float u_DepthMax;
out vec4 v_Color;

void main() {

  gl_Position = u_MvpMatrix * a_Position;

  if (gl_Position.z <= u_DepthMax) {
    v_Color = vec4(a_Position.x, a_Position.y, a_Position.z, gl_Position.z);
} else {
    v_Color = vec4(0.0, 0.0, 0.0, 0.0);
  }
}
`;

var offscreenFragmentShaderSource = `#version 300 es

precision highp float;

in vec4 v_Color;
out vec4 outXYZD;

void main() {
  outXYZD = v_Color;
}
`;

// --- Shared distortion shaders ---

var distortionVertexShaderSource = `#version 300 es

in vec4 a_Position;
in vec2 a_TexCoord;
out vec2 v_TexCoord;

void main() {
  gl_Position = a_Position;
  v_TexCoord = a_TexCoord;
}
`;

var distortionFragmentShaderSource = `#version 300 es

precision highp float;

in vec2 v_TexCoord;
uniform sampler2D u_Texture;
uniform vec3 u_DistortionCoefficients;
uniform float u_AspectRatio;  // width / height
out vec4 outColor;

void main() {

  // Map tex coords [0,1] to centered NDC [-1,1]
  vec2 ndc = v_TexCoord * 2.0 - 1.0;

  // Correct for aspect ratio so distortion is circular
  vec2 ndcCorrected = vec2(ndc.x * u_AspectRatio, ndc.y);

  float r_square = dot(ndcCorrected, ndcCorrected);
  float distortion = 1.0
    + u_DistortionCoefficients.x * r_square
    + u_DistortionCoefficients.y * r_square * r_square
    + u_DistortionCoefficients.z * r_square * r_square * r_square;

  // Apply distortion in original (uncorrected) NDC space
  vec2 distortedNdc = ndc * distortion;

  // Map back to tex coords [0,1]
  vec2 distortedUv = distortedNdc * 0.5 + 0.5;

  // Invisible outside bounds
  if (distortedUv.x < 0.0 || distortedUv.x > 1.0 ||
      distortedUv.y < 0.0 || distortedUv.y > 1.0) {
    outColor = vec4(0.0, 0.0, 0.0, 0.0);
  } else {
    outColor = texture(u_Texture, distortedUv);
  }
}
`;

function degToRad(d) {
  return d * Math.PI / 180;
}

// Set up WebGL state, called only once
function setupState() {
  var canvas = document.querySelector("#webgl");
  var gl = canvas.getContext("webgl2");
  if (!gl) {
    throw new Error("Unable to get WebGL2 context");
  }

  // Required for rendering to float textures (offscreen pipeline)
  var extFloat = gl.getExtension("EXT_color_buffer_float");
  if (!extFloat) {
    throw new Error("EXT_color_buffer_float not supported");
  }

  // Required for linear filtering on float textures (offscreen pipeline)
  var extFloatLinear = gl.getExtension("OES_texture_float_linear");
  if (!extFloatLinear) {
    throw new Error("OES_texture_float_linear not supported");
  }

  // Shift vertices to eyeInit to avoid floating-point precision issues
  for (var i = 0; i < geometry.vertices.length; i += 3) {
    geometry.vertices[i]     -= eyeInit[0];
    geometry.vertices[i + 1] -= eyeInit[1];
    geometry.vertices[i + 2] -= eyeInit[2];
  }

  // --- Display pipeline ---

  var programInfo = twgl.createProgramInfo(gl, [vertexShaderSource, fragmentShaderSource]);

  var arrays = {
    a_Position: { numComponents: 3, data: geometry.vertices },
    indices: geometry.indices,
  };
  var bufferInfo = twgl.createBufferInfoFromArrays(gl, arrays);
  var vao = twgl.createVAOFromBufferInfo(gl, programInfo, bufferInfo);

  var distortionProgramInfo = twgl.createProgramInfo(
    gl, [distortionVertexShaderSource, distortionFragmentShaderSource]
  );

  // Full-canvas quad to render distorted texture onto
  var quadArrays = {
    a_Position: { numComponents: 2, data: [-1, -1, 1, -1, -1, 1, 1, 1] },
    a_TexCoord: { numComponents: 2, data: [0, 0, 1, 0, 0, 1, 1, 1] },
    indices: [0, 1, 2, 2, 1, 3],
  };
  var quadBufferInfo = twgl.createBufferInfoFromArrays(gl, quadArrays);
  var quadVao = twgl.createVAOFromBufferInfo(gl, distortionProgramInfo, quadBufferInfo);

  var fboScene = twgl.createFramebufferInfo(gl, [
    { format: gl.RGBA, type: gl.UNSIGNED_BYTE, minMag: gl.LINEAR },
    { format: gl.DEPTH_COMPONENT16 },
  ], gl.canvas.width, gl.canvas.height);

  // --- Offscreen pipeline ---

  var offscreenProgramInfo = twgl.createProgramInfo(gl, [offscreenVertexShaderSource, offscreenFragmentShaderSource]);

  var offscreenBufferInfo = twgl.createBufferInfoFromArrays(gl, arrays);
  var offscreenVao = twgl.createVAOFromBufferInfo(gl, offscreenProgramInfo, offscreenBufferInfo);

  var offscreenDistortionProgramInfo = twgl.createProgramInfo(
    gl, [distortionVertexShaderSource, distortionFragmentShaderSource]
  );

  var offscreenQuadBufferInfo = twgl.createBufferInfoFromArrays(gl, quadArrays);
  var offscreenQuadVao = twgl.createVAOFromBufferInfo(gl, offscreenDistortionProgramInfo, offscreenQuadBufferInfo);

  var offscreenFboScene = twgl.createFramebufferInfo(gl, [
    { internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT, minMag: gl.LINEAR },
    { internalFormat: gl.DEPTH_COMPONENT24, attachmentPoint: gl.DEPTH_ATTACHMENT },
  ], gl.canvas.width, gl.canvas.height);

  var offscreenFboDistortion = twgl.createFramebufferInfo(gl, [
    { internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT, minMag: gl.LINEAR },
    { internalFormat: gl.DEPTH_COMPONENT24, attachmentPoint: gl.DEPTH_ATTACHMENT },
  ], gl.canvas.width, gl.canvas.height);

  gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

  return {  // WebGL state
    gl,

    // Display
    programInfo, bufferInfo, vao,
    distortionProgramInfo, quadBufferInfo, quadVao,
    fboScene,

    // Offscreen
    offscreenProgramInfo, offscreenBufferInfo, offscreenVao,
    offscreenDistortionProgramInfo, offscreenQuadBufferInfo, offscreenQuadVao,
    offscreenFboScene, offscreenFboDistortion,
  };
}

function buildViewProjectionMatrix(gl, eye, RFU, fov, depthMax) {
  var projectionMatrix = twgl.m4.perspective(
    degToRad(fov),
    gl.canvas.width / gl.canvas.height,
    1,
    depthMax
  );

  var forward = [RFU[3], RFU[4], RFU[5]];
  var up = [RFU[6], RFU[7], RFU[8]];

  eye = [eye[0] - eyeInit[0], eye[1] - eyeInit[1], eye[2] - eyeInit[2]];
  var target = [eye[0] + forward[0], eye[1] + forward[1], eye[2] + forward[2]];

  var cameraMatrix = twgl.m4.lookAt(eye, target, up);
  var viewMatrix = twgl.m4.inverse(cameraMatrix);
  return twgl.m4.multiply(projectionMatrix, viewMatrix);
}

// Render depthmap on canvas
function render(state, eye, RFU, fov, depthMax, distortionCoefficients) {
  var { gl, programInfo, bufferInfo, vao, distortionProgramInfo, quadBufferInfo, quadVao, fboScene } = state;

  // --- Pass 1: Render scene to framebuffer ---

  twgl.bindFramebufferInfo(gl, fboScene);
  gl.enable(gl.DEPTH_TEST);
  gl.enable(gl.CULL_FACE);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

  gl.useProgram(programInfo.program);
  gl.bindVertexArray(vao);

  var viewProjectionMatrix = buildViewProjectionMatrix(gl, eye, RFU, fov, depthMax);

  twgl.setUniforms(programInfo, {
    u_MvpMatrix: viewProjectionMatrix,
    u_DepthMax: depthMax
  });
  twgl.drawBufferInfo(gl, bufferInfo);

  // --- Pass 2: Apply lens distortion as post-process ---

  twgl.bindFramebufferInfo(gl, null);  // render to canvas
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.disable(gl.DEPTH_TEST);
  gl.disable(gl.CULL_FACE);

  gl.useProgram(distortionProgramInfo.program);
  gl.bindVertexArray(quadVao);

  twgl.setUniforms(distortionProgramInfo, {
    u_Texture: fboScene.attachments[0],
    u_DistortionCoefficients: distortionCoefficients,
    u_AspectRatio: gl.canvas.width / gl.canvas.height,
  });
  twgl.drawBufferInfo(gl, quadBufferInfo);

  var error = gl.getError();
  if (error != gl.NO_ERROR) {
    console.warn(error);
  }
}

// Render all coordinate and depth maps to off-screen buffer
function offscreenRender(state, eye, RFU, fov, depthMax, distortionCoefficients) {
  var {
    gl,
    offscreenProgramInfo, offscreenBufferInfo, offscreenVao,
    offscreenDistortionProgramInfo, offscreenQuadBufferInfo, offscreenQuadVao,
    offscreenFboScene, offscreenFboDistortion,
  } = state;

  // --- Pass 1: Render scene to float framebuffer ---

  twgl.bindFramebufferInfo(gl, offscreenFboScene);
  gl.enable(gl.DEPTH_TEST);
  gl.enable(gl.CULL_FACE);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

  gl.useProgram(offscreenProgramInfo.program);
  gl.bindVertexArray(offscreenVao);

  var viewProjectionMatrix = buildViewProjectionMatrix(gl, eye, RFU, fov, depthMax);

  twgl.setUniforms(offscreenProgramInfo, {
    u_MvpMatrix: viewProjectionMatrix,
    u_DepthMax: depthMax
  });
  twgl.drawBufferInfo(gl, offscreenBufferInfo);

  // --- Pass 2: Apply lens distortion as post-process ---

  twgl.bindFramebufferInfo(gl, offscreenFboDistortion);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.disable(gl.DEPTH_TEST);
  gl.disable(gl.CULL_FACE);

  gl.useProgram(offscreenDistortionProgramInfo.program);
  gl.bindVertexArray(offscreenQuadVao);

  twgl.setUniforms(offscreenDistortionProgramInfo, {
    u_Texture: offscreenFboScene.attachments[0],
    u_DistortionCoefficients: distortionCoefficients,
    u_AspectRatio: gl.canvas.width / gl.canvas.height,
  });
  twgl.drawBufferInfo(gl, offscreenQuadBufferInfo);

  // Read back float pixels from offscreenFboDistortion
  var pixels = new Float32Array(gl.canvas.width * gl.canvas.height * 4);  // XYZD
  gl.readPixels(0, 0, gl.canvas.width, gl.canvas.height, gl.RGBA, gl.FLOAT, pixels);

  var error = gl.getError();
  if (error != gl.NO_ERROR) {
    console.warn(error);
  }

  return pixels;
}

function ensureState(message) {
  if (!state) {
    eyeInit = message.eyeInit;
    state = setupState();
  }
}

Shiny.addCustomMessageHandler("render", function (message) {
  ensureState(message);
  render(state, message.eye, message.RFU, message.fov, message.depthMax, message.distortionCoefficients);
});

Shiny.addCustomMessageHandler("offscreenRender", function (message) {
  ensureState(message);
  var pixels = offscreenRender(state, message.eye, message.RFU, message.fov, message.depthMax, message.distortionCoefficients);

  // Undo shift of eyeInit to XYZ part of pixels
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] !== 0) {  // skip background pixels
      pixels[i]     += eyeInit[0];
      pixels[i + 1] += eyeInit[1];
      pixels[i + 2] += eyeInit[2];
    }
  }

  // Convert Float32Array to base64
  var bytes = new Uint8Array(pixels.buffer);
  var binary = "";
  for (var i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  var base64 = btoa(binary);

  // Send array back to Shiny
  Shiny.setInputValue("save_fbo", {
    bytes: base64,
    view: message.view
  });
});

Shiny.addCustomMessageHandler('setOpacity', function (opacity) {
  document.getElementById('webgl').style.opacity = opacity;
});