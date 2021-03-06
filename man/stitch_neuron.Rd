% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stitch_neuron.R
\name{stitch_neuron}
\alias{stitch_neuron}
\title{Stitch two neurons together at their closest endpoints}
\usage{
stitch_neuron(a, b)
}
\arguments{
\item{a, b}{Neurons to join together}
}
\description{
Stitch two neurons together at their closest endpoints
}
\details{
Note that for CATMAID neurons the neuron with the soma tag will be
  treated as the first (master neuron). Furthermore in this case the PointNo
  (aka node id) should already be unique. Otherwise it will be adjusted to
  ensure this.
}
\seealso{
\code{\link{stitch_neurons}}
}
