# Export the Plum Island Ecosystems data set shipped with lulcc to GeoTIFF,
# so that the replication can read it without R.
#
# Output: goldens/data/<layer>.tif, one file per layer of `pie`
#   lu_pie_1985, lu_pie_1991, lu_pie_1999  land use (1 Forest, 2 Built, 3 Other)
#   ef_001 elevation, ef_002 slope, ef_003 distance to built land in 1985

source("scripts/common.R")

d <- out_dir("data")
p <- load_pie()

rows <- list()
for (name in names(p$pie)) {
  r <- p$pie[[name]]
  is_lu <- grepl("^lu_", name)
  path <- file.path(d, paste0(name, ".tif"))
  raster::writeRaster(r, filename = path, format = "GTiff",
                      datatype = if (is_lu) "INT1U" else "FLT8S",
                      NAflag = if (is_lu) 255 else -9999,
                      options = c("COMPRESS=DEFLATE"), overwrite = TRUE)
  v <- raster::getValues(r)
  rows[[length(rows) + 1]] <- data.frame(
    layer = name,
    nrow = nrow(r), ncol = ncol(r),
    xmin = xmin(r), ymax = ymax(r), res_x = xres(r), res_y = yres(r),
    crs = as.character(raster::crs(r)),
    n_valid = sum(!is.na(v)),
    min = suppressWarnings(min(v, na.rm = TRUE)),
    max = suppressWarnings(max(v, na.rm = TRUE)),
    sum = sum(v, na.rm = TRUE)
  )
}
write_csv(do.call(rbind, rows), file.path(d, "layers.csv"))

# Observed transitions: the first numbers of the paper (Sect. 3.2), which
# depend on the data only and must match exactly.
write_csv(rbind(crosstab_long(p$obs, c(0, 14)),
                crosstab_long(p$obs, c(0, 6)),
                crosstab_long(p$obs, c(6, 14))),
          file.path(d, "crosstab.csv"))

cat("data exported to", d, "\n")
