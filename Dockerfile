FROM rocker/r-ver:latest
MAINTAINER Julia Palm <julia.palm@med.uni-jena.de>
LABEL Description="PJT#6 smith2"
RUN mkdir -p /Ergebnisse
RUN mkdir -p /errors
RUN mkdir -p /Bundles
COPY config.R.default config.R.default
COPY smith_select.R smith_select.R
COPY install_R_packages.R install_R_packages.R
RUN apt-get update -qq
RUN apt-get install -yqq libxml2-dev libssl-dev curl
RUN install2.r --error \
  --deps TRUE \
  fhircrackr
  
CMD Rscript smith_select.R