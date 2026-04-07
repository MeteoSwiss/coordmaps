# Copyright (c) 2026 MeteoSwiss, contributors listed in AUTHORS
# Distributed under the terms of the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

test_that("cross_product computes 3D cross product correctly", {

  # Standard basis vectors
  expect_equal(cross_product(c(1, 0, 0), c(0, 1, 0)), c(0, 0, 1))
  expect_equal(cross_product(c(0, 1, 0), c(0, 0, 1)), c(1, 0, 0))
  expect_equal(cross_product(c(0, 0, 1), c(1, 0, 0)), c(0, 1, 0))

  # Anti-commutativity: a x b == -(b x a)
  a <- c(1, 2, 3)
  b <- c(4, 5, 6)
  expect_equal(cross_product(a, b), -cross_product(b, a))

  # Parallel vectors produce zero vector
  expect_equal(cross_product(c(1, 2, 3), c(2, 4, 6)), c(0, 0, 0))
})