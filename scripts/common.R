# Shared setup for the lulcc-goldens scripts.
#
# Everything here follows demo/gmd-paper.R of lulcc 1.0.4, which is the
# script behind Moulds, Buytaert & Mijic (2015), Geosci. Model Dev. 8,
# 3215-3229, doi:10.5194/gmd-8-3215-2015.

suppressPackageStartupMessages({
  library(lulcc)
  library(raster)
})

OUT <- Sys.getenv("GOLDENS_DIR", "goldens")

out_dir <- function(...) {
  d <- file.path(OUT, ...)
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}

CATEGORIES <- c(1, 2, 3)
LABELS <- c("Forest", "Built", "Other")
FACTORS <- 2^(1:8)  # resolutions used in Figs. 7 and 8 of the paper

# Formulas as in the paper (Sect. 3.3) and the demo.
FORMS <- list(Built ~ ef_001 + ef_002 + ef_003,
              Forest ~ ef_001 + ef_002,
              Other ~ ef_001 + ef_002)

# CLUE-S parameters as in the paper (Sect. 3.5.2).
CLUES_PARAMS <- list(jitter.f = 0.0002,
                     scale.f = 0.000001,
                     max.iter = 1000,
                     max.diff = 50,
                     ave.diff = 50)
CLUES_ELAS <- c(0.2, 0.2, 0.2)
ORDERED_ORDER <- c(2, 1, 3)  # built, forest, other

# The `pie` rasters were saved with a CRS object from before PROJ 6. With
# current raster/sp, a raster created from them carries a WKT2 CRS, and
# allocate() stops with "different crs" when it stacks the simulated map
# on the initial one (compareRaster in R/allocate.R). Re-assigning the same
# CRS in the current form fixes it. Coordinates, extent and values are not
# touched, and nothing in lulcc's computations depends on the CRS. Whether
# the fix was needed is recorded in goldens/crs_refreshed.txt.
refresh_crs <- function(pie) {
  ref <- raster::raster(pie[[1]])
  needed <- !raster::compareRaster(pie[[1]], ref, crs = TRUE, stopiffalse = FALSE)
  if (needed) {
    for (n in names(pie)) raster::crs(pie[[n]]) <- raster::crs(ref)
  }
  dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
  writeLines(c(paste0("crs_refreshed: ", needed),
               paste0("raster: ", packageVersion("raster")),
               paste0("sp: ", packageVersion("sp"))),
             file.path(OUT, "crs_refreshed.txt"))
  pie
}

load_pie <- function() {
  e <- new.env()
  data("pie", package = "lulcc", envir = e)
  pie <- refresh_crs(e$pie)
  obs <- ObsLulcRasterStack(x = pie,
                            pattern = "lu",
                            categories = CATEGORIES,
                            labels = LABELS,
                            t = c(0, 6, 14))
  ef <- ExpVarRasterList(x = pie, pattern = "ef")
  ef <- resample(ef, obs)
  list(pie = pie, obs = obs, ef = ef)
}

write_csv <- function(df, path) {
  if (grepl("\\.gz$", path)) {
    con <- gzfile(path, "w")
    on.exit(close(con))
    utils::write.csv(df, con, row.names = FALSE)
  } else {
    utils::write.csv(df, path, row.names = FALSE)
  }
  invisible(path)
}

# Land use maps as one multiband GeoTIFF (band 1 = t0, band 15 = t14).
write_maps <- function(stack, path) {
  raster::writeRaster(stack, filename = path, format = "GTiff",
                      datatype = "INT1U", NAflag = 255,
                      options = c("COMPRESS=DEFLATE"), overwrite = TRUE)
  invisible(path)
}

# Raster cell numbers (1-based, row-major, as in raster::cellFromXY).
cells_of <- function(x, points) {
  raster::cellFromXY(x, points)
}

glm_coefficients <- function(models) {
  rows <- list()
  for (i in seq_along(models@models)) {
    m <- models@models[[i]]
    co <- stats::coef(m)
    rows[[i]] <- data.frame(category = models@categories[i],
                            label = models@labels[i],
                            term = names(co),
                            estimate = unname(co),
                            n_train = length(m$y))
  }
  do.call(rbind, rows)
}

# AUC with full precision (compareAUC() rounds to 4 digits).
auc_table <- function(pred, model_name) {
  auc <- vapply(pred@prediction,
                function(p) ROCR::performance(p, measure = "auc")@y.values[[1]],
                numeric(1))
  data.frame(model = model_name, category = pred@categories,
             label = pred@labels, auc = unname(auc))
}

crosstab_long <- function(obs, times) {
  tab <- crossTabulate(x = obs, times = times)
  m <- as.matrix(tab)
  data.frame(t_from = times[1], t_to = times[2],
             from = rep(rownames(m), times = ncol(m)),
             to = rep(colnames(m), each = nrow(m)),
             cells = as.vector(m))
}

# The three-map contingency tables are the source of every validation
# number in the paper; keeping them lets the Python side recompute the
# agreement budget and the figure of merit independently.
tables_long <- function(tabs) {
  rows <- list()
  for (f in seq_along(tabs@tables)) {
    tab <- as.matrix(tabs@tables[[f]])
    rows[[f]] <- data.frame(factor = tabs@factors[f],
                            row = as.vector(row(tab)),
                            col = as.vector(col(tab)),
                            value = as.vector(tab))
  }
  do.call(rbind, rows)
}

agreement_long <- function(agr) {
  add <- function(df, level, name) {
    cbind(data.frame(level = level, name = name, factor = agr@factors), df)
  }
  rows <- list(add(agr@overall, "overall", "all"))
  for (n in names(agr@category)) {
    rows[[length(rows) + 1]] <- add(agr@category[[n]], "category", n)
  }
  for (n in names(agr@transition)) {
    d <- agr@transition[[n]]
    if (!"e" %in% names(d)) d$e <- NA  # transitions have no correct persistence
    rows[[length(rows) + 1]] <- add(d, "transition", n)
  }
  do.call(rbind, rows)
}

# fom@transition[[f]][i, j] is the transition from category i to j
# (same indexing as .agreementBudget and plot(fom, from, to)).
fom_long <- function(fom) {
  rows <- list()
  labs <- fom@labels
  for (f in seq_along(fom@factors)) {
    fac <- fom@factors[f]
    rows[[length(rows) + 1]] <- data.frame(factor = fac, level = "overall",
                                           from = NA, to = NA,
                                           fom = fom@overall[[f]])
    rows[[length(rows) + 1]] <- data.frame(factor = fac, level = "category",
                                           from = labs, to = NA,
                                           fom = unname(fom@category[[f]]))
    tr <- fom@transition[[f]]
    n <- nrow(tr)
    rows[[length(rows) + 1]] <- data.frame(factor = fac, level = "transition",
                                           from = labs[rep(seq_len(n), times = n)],
                                           to = labs[rep(seq_len(n), each = n)],
                                           fom = as.vector(tr))
  }
  do.call(rbind, rows)
}

validate_model <- function(model, dir, prefix) {
  tabs <- ThreeMapComparison(x = model, factors = FACTORS, timestep = 14)
  agr <- AgreementBudget(x = tabs)
  fom <- FigureOfMerit(x = tabs)
  write_csv(tables_long(tabs), file.path(dir, paste0(prefix, "_tables.csv")))
  write_csv(agreement_long(agr), file.path(dir, paste0(prefix, "_agreement.csv")))
  write_csv(fom_long(fom), file.path(dir, paste0(prefix, "_fom.csv")))
  invisible(fom)
}

timed <- function(expr) {
  t <- system.time(value <- force(expr))
  list(value = value, seconds = unname(t[["elapsed"]]))
}
