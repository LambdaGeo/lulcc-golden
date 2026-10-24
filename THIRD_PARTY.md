# Third-party software and data

## lulcc

- R package **lulcc** 1.0.4, Simon Moulds. Licence: GPL (>= 2).
  https://cran.r-project.org/package=lulcc
- Installed from CRAN (dated Posit Package Manager snapshot, see the
  `Dockerfile`); it is not copied into this repository.
- The goldens are outputs of running lulcc. No lulcc source code is
  included here.

## Plum Island Ecosystems data (`pie`)

- Shipped with lulcc as `data(pie)`: land use in 1985, 1991 and 1999
  (forest, built, other) and three explanatory variables (elevation, slope,
  distance to built land in 1985).
- Origin, as documented in lulcc: MassGIS (Massachusetts Geographic
  Information System), processed by Pontius & Parmentier (2014),
  *Landscape Ecology* 29, 367–382, doi:10.1007/s10980-013-9984-8. The
  compilation was supported by the US National Science Foundation (grant
  OEC-1238212), as acknowledged in Moulds et al. (2015).
- lulcc does not state a separate licence for the data set; it is
  distributed inside a GPL (>= 2) package.

**To do before the first release:** confirm that the GeoTIFF copies in
`goldens/data/` may be redistributed under the licence of this repository's
Zenodo record. If not, keep only `scripts/export_pie.R` and the checksums,
and let users regenerate the files.

## Not used

The `sibuyan` data set of lulcc is documented as modified by Peter Verburg
for demonstration only ("should not be used for purposes other than
demonstration"). It is not exported here.
