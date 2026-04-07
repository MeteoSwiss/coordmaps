# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

#' 3D vector cross product
#'
#' @param a  3d vector
#' @param b  3d vector
#'
cross_product <- function(a, b) {

  c1 <- a[2]*b[3] - b[2]*a[3]
  c2 <- b[1]*a[3] - a[1]*b[3]
  c3 <- a[1]*b[2] - b[1]*a[2]

  return (c(c1, c2, c3))
}

#' Modified Gram-Schmidt orthogonalization of matrix X
#'
#' See https://www.r-bloggers.com/qr-decomposition-with-the-gram-schmidt-algorithm/
#'
#' @param X  matrix to be orthogonalized
#'
gramschmidt <- function(X) {

  X <- as.matrix(X)
  n <- ncol(X)
  m <- nrow(X)

  Q <- matrix(0, m, n)
  R <- matrix(0, n, n)

  for (j in 1:n) {
    v = X[ ,j]  # Step 1 of the Gram-Schmidt process v1 = a1
    if (j > 1) {
      for (i in 1:(j-1)) {
        R[i,j] <- t(Q[ ,i]) %*% X[ ,j]
        # Subtract the projection from v which causes v to become perpendicular to all columns of Q
        v <- v - R[i,j] * Q[ ,i]
      }
    }
    R[j,j] <- sqrt(sum(v^2))
    Q[ ,j] <- v / R[j,j]
  }

  return(Q)
}

#' Create a 3D rotation matrix
#'
#' @param a  rotation axis 3D vector
#' @param t  rotation angle in degrees
#
rotation_matrix <- function(a, t) {

  a <- a/sqrt(sum(a^2))
  t <- pi*t/180

  R <- c(
    cos(t)+a[1]^2*(1-cos(t)), a[1]*a[2]*(1-cos(t))-a[3]*sin(t), a[1]*a[3]*(1-cos(t))+a[2]*sin(t),
    a[2]*a[1]*(1-cos(t))+a[3]*sin(t), cos(t)+a[2]^2*(1-cos(t)), a[2]*a[3]*(1-cos(t))-a[1]*sin(t),
    a[3]*a[1]*(1-cos(t))-a[2]*sin(t), a[3]*a[2]*(1-cos(t))+a[1]*sin(t), cos(t)+a[3]^2*(1-cos(t))
  )
  R <- matrix(t(R), 3)

  return(R)
}

#' Rotate matrix along a specific axis
#'
#' @param RFU  matrix to be rotated
#' @param axis  rotation axis 3D vector
#' @param degrees  degrees to rotate
#'
rotate <- function(RFU, axis, degrees) {

    R <- rotation_matrix(axis, degrees)
    RFU <- R%*%RFU |>
      gramschmidt()

  return(RFU)
}