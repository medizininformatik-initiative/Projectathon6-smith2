FROM rocker/r-ver:latest

# MAINTAINER Julia Palm <julia.palm@med.uni-jena.de>
LABEL Description="PJT#6 Consent Extraction"
LABEL Maintainer="julia.palm@med.uni-jena.de"

RUN mkdir -p /Ergebnisse

RUN apt-get update -qq
RUN apt-get install -yqq libxml2-dev libssl-dev curl
RUN install2.r --error \
  --deps TRUE \
  fhircrackr

COPY config.R.default config.R.default
COPY consent.R consent.R
COPY install_R_packages.R install_R_packages.R

CMD ["Rscript", "consent.R"]
