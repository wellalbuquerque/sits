% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_torch_spatial_encoder.R
\name{.torch_pixel_spatial_encoder}
\alias{.torch_pixel_spatial_encoder}
\alias{.torch_pixel_spatial_enconder}
\title{Torch module for spatial encoder}
\usage{
.torch_pixel_spatial_enconder(n_bands, layers_mlp2 = c(32, 64, 128))
}
\arguments{
\item{n_bands}{Number of bands per pixel.}

\item{layers_mlp2}{Layers of MLP2 spatial encoder}
}
\value{
A linear tensor block.
}
\description{
Defines a torch module for spatial encoding.

This function is adapted from the paper by Vivien Garnot referenced below
and code available on github at
https://github.com/VSainteuf/lightweight-temporal-attention-pytorch/blob/master/models/ltae.py.
If you use this method, please cite the original LTAE paper.

There is an important difference: the model
proposed by Garnot assumes that the samples are available by parcel.
In his model, the samples from the same parcel are averaged using an MLP.
The current function implements an alternative to Garnot's pixel set
encoder for the case when only individual pixels are available.

The spatial encoder is run for each temporal instance of the observations.
Thus it transforms a pixel with n bands to a pixel associated with an output
dimension of a linear encoder.

The input of the PSE is a tuple of tensors of the form:
Pixel-Set: (Batch_size x Time Sequence Length) x Number of Bands

 Since the input tensors have a temporal dimension, this dimension
 will be combined with the batch dimension so that the complete sequences
 are processed at once.
 Then the temporal dimension is separated back to produce a tensor of
 shape Batch_size x Time Sequence length x Embedding dimension
}
\references{
Vivien Sainte Fare Garnot and Loic Landrieu,
"Lightweight Temporal Self-Attention
for Classifying Satellite Image Time Series", https://arxiv.org/abs/2007.00586
}
\author{
Charlotte Pelletier, \email{charlotte.pelletier@univ-ubs.fr}

Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}

Felipe Souza, \email{lipecaso@gmail.com}
}
\keyword{internal}
