test_that("Labels", {
  # skip_on_cran()

  labels <- sits_labels_summary(samples_modis_4bands)

  expect_true("Cerrado" %in% sits_labels(samples_modis_4bands))
  expect_equal(sum(labels$count), 1218)
  expect_equal(labels$label[1], "Cerrado")
  expect_equal(sum(labels$prop), 1)

  samples_mt_ndvi <- sits_select(samples_modis_4bands, bands = "NDVI")
  model <- sits_train(samples_mt_ndvi, sits_svm())

  expect_equal(sits_labels(model), sits_labels(samples_mt_ndvi))

  expect_equal(sits_bands(model), sits_bands(samples_mt_ndvi))
})

test_that("Relabel", {
  # skip_on_cran()

  data("samples_modis_4bands")

  # copy result
  new_data <- samples_modis_4bands
  sits_labels(new_data) #  [1] "Cerrado"  "Forest"   "Pasture"  "Soy_Corn"

  sits_labels(new_data) <- c("Cerrado", "Forest", "Pasture", "Cropland")

  labels <- sits_labels_summary(new_data)

  expect_true("Cropland" %in% sits_labels(new_data))
  expect_equal(length(labels$label), 4)
  expect_equal(labels$label[1], "Cerrado")
  expect_equal(sum(labels$prop), 1)
})
