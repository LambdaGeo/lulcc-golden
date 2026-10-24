# Environment that generates the lulcc goldens.
#
# BASE_IMAGE: replace the tag with its digest (rocker/geospatial@sha256:...)
# before the first release; `make pin` prints it.
# CRAN_SNAPSHOT: dated Posit Package Manager snapshot, so every package
# version is fixed by the date. lulcc 1.0.4 was republished on CRAN on
# 2025-11-08, so the snapshot must be later than that.

ARG BASE_IMAGE=rocker/geospatial:4.5.1
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG CRAN_SNAPSHOT=2026-10-01
ENV BASE_IMAGE=${BASE_IMAGE} \
    CRAN_REPO=https://packagemanager.posit.co/cran/__linux__/noble/${CRAN_SNAPSHOT}

RUN Rscript -e "options(repos = c(CRAN = Sys.getenv('CRAN_REPO'))); \
      install.packages(c('lulcc', 'raster', 'rasterVis', 'ROCR', 'caret', \
                         'rpart', 'randomForest', 'Hmisc', 'RColorBrewer', 'gsubfn', 'plyr', \
                         'jsonlite'))" \
 && Rscript -e "stopifnot(packageVersion('lulcc') == '1.0.4'); \
      library(lulcc); data(pie); cat('lulcc', as.character(packageVersion('lulcc')), 'OK\n')"

WORKDIR /work
