% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_plot.R
\name{plot.predicted}
\alias{plot.predicted}
\title{Plot time series predictions}
\usage{
\method{plot}{predicted}(x, y, ..., bands = "NDVI", palette = "Harmonic")
}
\arguments{
\item{x}{Object of class "predicted".}

\item{y}{Ignored.}

\item{...}{Further specifications for \link{plot}.}

\item{bands}{Bands for visualisation.}

\item{palette}{HCL palette used for visualisation
in case classes are not in the default sits palette.}
}
\value{
The plot itself.
}
\description{
Given a sits tibble with a set of predictions, plot them
}
\examples{
\dontrun{
# Retrieve the set of samples for Mato Grosso region (provided by EMBRAPA)
samples_mt_ndvi <- sits_select(samples_modis_4bands, bands = "NDVI")
# classify the point
model_svm <- sits_train(samples_mt_ndvi, ml_method = sits_svm())
point_ndvi <- sits_select(point_mt_6bands, bands = "NDVI")
class_ndvi.tb <- sits_classify(point_ndvi, model_svm)
# plot the classification
plot(class_ndvi.tb)
}

}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
