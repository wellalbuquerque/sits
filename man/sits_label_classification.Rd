% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_label_classification.R
\name{sits_label_classification}
\alias{sits_label_classification}
\title{Build a labelled image from a probability cube}
\usage{
sits_label_classification(
  cube,
  multicores = 2,
  memsize = 4,
  output_dir = ".",
  version = "v1"
)
}
\arguments{
\item{cube}{Classified image data cube.}

\item{multicores}{Number of workers to label the classification in
parallel.}

\item{memsize}{maximum overall memory (in GB) to label the
classification.}

\item{output_dir}{Output directory for classified files.}

\item{version}{Version of resulting image
(in the case of multiple runs).}
}
\value{
A data cube
}
\description{
Takes a set of classified raster layers with probabilities,
             and label them based on the maximum probability for each pixel.
}
\examples{
\dontrun{
# Retrieve the samples for Mato Grosso
# select band "ndvi"
samples_ndvi <- sits_select(samples_modis_4bands, bands = "NDVI")

# select a random forest model
rfor_model <- sits_train(samples_ndvi, sits_rfor(num_trees = 500))

# create a data cube based on the information about the files
data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
cube <- sits_cube(
  source = "BDC",
  collection = "MOD13Q1-6",
  data_dir = data_dir,
  delim = "_",
  parse_info = c("X1", "X2", "tile", "band", "date")
)

# classify the raster image
probs_cube <- sits_classify(cube,
  ml_model = rfor_model,
  output_dir = tempdir(),
  memsize = 4, multicores = 2
)

# label the classification
label_cube <- sits_label_classification(probs_cube, output_dir = tempdir())
}

}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}
