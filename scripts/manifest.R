# Record the environment the goldens were generated in.
#
# goldens/environment.json  R, platform, RNG, versions and build data of
# the packages that affect the results (including lulcc's Packaged and
# Date/Publication fields: lulcc 1.0.4 was packaged in 2019 and
# republished on CRAN in 2025 with the same version number).

source("scripts/common.R")

pkgs <- c("lulcc", "raster", "terra", "sp", "ROCR", "caret", "rpart",
          "randomForest", "Hmisc", "rasterVis", "lattice")

pkg_info <- lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) return(NULL)
  desc <- utils::packageDescription(p)
  list(package = p,
       version = desc$Version,
       packaged = desc$Packaged,
       publication = desc[["Date/Publication"]],
       repository = desc$Repository,
       built = desc$Built)
})
names(pkg_info) <- pkgs

info <- list(
  generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  r_version = R.version.string,
  platform = R.version$platform,
  rng_kind = RNGkind(),
  cran_repo = Sys.getenv("CRAN_REPO"),
  base_image = Sys.getenv("BASE_IMAGE"),
  gdal = tryCatch(as.character(terra::gdal()), error = function(e) NA),
  packages = Filter(Negate(is.null), pkg_info)
)

jsonlite::write_json(info, file.path(OUT, "environment.json"),
                     auto_unbox = TRUE, pretty = TRUE)
writeLines(utils::capture.output(utils::sessionInfo()),
           file.path(OUT, "sessionInfo.txt"))
cat("environment written to", file.path(OUT, "environment.json"), "\n")
