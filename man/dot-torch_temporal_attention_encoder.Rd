% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_torch_temporal_attention_encoder.R
\name{.torch_temporal_attention_encoder}
\alias{.torch_temporal_attention_encoder}
\title{Torch module for temporal attention encoder}
\usage{
.torch_temporal_attention_encoder(
  timeline,
  dim_encoder = 128,
  n_heads = 4,
  dim_input_mlp3 = 512,
  dim_layers_mlp3 = c(128, 128)
)
}
\arguments{
\item{timeline}{Timeline of input time series.}

\item{dim_encoder}{Dimension of the positional enconder.}

\item{n_heads}{Number of attention heads.}

\item{dim_input_mlp3}{Dimension of input to multi-layer perceptron
(MLP3 in Garnot's paper)}

\item{dim_q_k}{Shared dimensions of keys and queries for attention.}

\item{dim_hidden_nodes_mlp3}{Dimensions of hidden nodes in multi-layer
perceptrons (MLP3 in Garnot's paper)}
}
\value{
A linear tensor block.
}
\description{
Defines a torch module for temporal attention encoding.

This function part of the implementation of the paper by Vivien Garnot
referenced below.
We used the code made available by Maja Schneider in her work with
Marco Körner referenced below and available at
https://github.com/maja601/RC2020-psetae.
}
\references{
Vivien Sainte Fare Garnot and Loic Landrieu,
"Lightweight Temporal Self-Attention
for Classifying Satellite Image Time Series", https://arxiv.org/abs/2007.00586

Schneider, Maja; Körner, Marco,
"[Re] Satellite Image Time Series Classification
with Pixel-Set Encoders and Temporal Self-Attention." ReScience C 7 (2), 2021.
}
\author{
Charlotte Pelletier, \email{charlotte.pelletier@univ-ubs.fr}

Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}

Felipe Souza, \email{lipecaso@gmail.com}
}
\keyword{internal}
