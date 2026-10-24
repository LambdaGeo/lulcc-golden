# Ensemble golden: demo/gmd-paper.R run as published, once per seed.
#
# The paper sets no seed. The demo draws random numbers in this order:
# partition (caret), randomForest fitting, CLUE-S jitter, ordered
# stochastic allocation. This script keeps that order, so seed s gives one
# possible run of the paper, and the set of seeds gives the spread the
# replication is compared against.
#
# Usage: Rscript scripts/ensemble.R [n_seeds] [first_seed]
#
# Per seed (goldens/ensemble/seed_NNN/):
#   auc.csv                AUCs of Fig. 5 (glm, rpart, rf; test partition 1985)
#   auc_builtgain.csv      AUC of Fig. 6 (glm, gain of built 1985-1991)
#   glm_coefficients.csv
#   clues_maps.tif, ordered_maps.tif
#   <model>_tables.csv, _agreement.csv, _fom.csv   (Figs. 7 and 8)
#   timing.csv
# And goldens/ensemble/summary_*.csv across seeds.

source("scripts/common.R")

args <- commandArgs(trailingOnly = TRUE)
n_seeds <- if (length(args) >= 1) as.integer(args[1]) else 30L
first <- if (length(args) >= 2) as.integer(args[2]) else 1L
seeds <- seq(first, length.out = n_seeds)

p <- load_pie()
obs <- p$obs
ef <- p$ef
dmd <- approxExtrapDemand(obs = obs, tout = 0:14)  # deterministic
rules <- matrix(data = 1, nrow = 3, ncol = 3, byrow = TRUE)

run_seed <- function(seed) {
  d <- out_dir("ensemble", sprintf("seed_%03d", seed))
  set.seed(seed)

  part <- partition(x = obs[[1]], size = 0.1, spatial = TRUE)
  train.data <- getPredictiveModelInputData(obs = obs, ef = ef, cells = part[["train"]])
  glm.models <- glmModels(formula = FORMS, family = binomial, data = train.data, obs = obs)
  rpart.models <- rpartModels(formula = FORMS, data = train.data, obs = obs)
  rf.models <- randomForestModels(formula = FORMS, data = train.data, obs = obs)
  write_csv(glm_coefficients(glm.models), file.path(d, "glm_coefficients.csv"))

  # Fig. 5
  test.data <- getPredictiveModelInputData(obs = obs, ef = ef, cells = part[["test"]])
  auc <- rbind(
    auc_table(PredictionList(models = glm.models, newdata = test.data), "glm"),
    auc_table(PredictionList(models = rpart.models, newdata = test.data), "rpart"),
    auc_table(PredictionList(models = rf.models, newdata = test.data), "rf"))
  write_csv(cbind(seed = seed, auc), file.path(d, "auc.csv"))

  # Fig. 6
  gain <- rasterToPoints(obs[[1]], fun = function(x) x != 2, spatial = TRUE)
  gain.data <- getPredictiveModelInputData(obs = obs, ef = ef, cells = gain, t = 6)
  gain.auc <- auc_table(PredictionList(models = glm.models[[2]], newdata = gain.data), "glm")
  write_csv(cbind(seed = seed, gain.auc), file.path(d, "auc_builtgain.csv"))

  clues.model <- CluesModel(obs = obs, ef = ef, models = glm.models,
                            time = 0:14, demand = dmd, elas = CLUES_ELAS,
                            rules = rules, params = CLUES_PARAMS)
  ordered.model <- OrderedModel(obs = obs, ef = ef, models = glm.models,
                                time = 0:14, demand = dmd, order = ORDERED_ORDER)

  tc <- timed(allocate(clues.model))
  clues.model <- tc$value
  to <- timed(allocate(ordered.model, stochastic = TRUE))
  ordered.model <- to$value

  write_maps(clues.model@output, file.path(d, "clues_maps.tif"))
  write_maps(ordered.model@output, file.path(d, "ordered_maps.tif"))
  clues.fom <- validate_model(clues.model, d, "clues")
  ordered.fom <- validate_model(ordered.model, d, "ordered")

  write_csv(data.frame(seed = seed, step = c("clues", "ordered"),
                       seconds = c(tc$seconds, to$seconds)),
            file.path(d, "timing.csv"))

  fb <- function(fom, model) {
    x <- fom_long(fom)
    x <- x[x$level == "transition" & x$from == "Forest" & x$to == "Built", ]
    data.frame(seed = seed, model = model, factor = x$factor, fom = x$fom)
  }
  list(auc = cbind(seed = seed, auc),
       gain = cbind(seed = seed, gain.auc),
       fom = rbind(fb(clues.fom, "clues"), fb(ordered.fom, "ordered")),
       timing = data.frame(seed = seed, step = c("clues", "ordered"),
                           seconds = c(tc$seconds, to$seconds)))
}

res <- list()
for (s in seeds) {
  cat(sprintf("seed %d (%d of %d)\n", s, match(s, seeds), length(seeds)))
  res[[length(res) + 1]] <- run_seed(s)
}

d <- out_dir("ensemble")
collect <- function(key) do.call(rbind, lapply(res, `[[`, key))
write_csv(collect("auc"), file.path(d, "summary_auc.csv"))
write_csv(collect("gain"), file.path(d, "summary_auc_builtgain.csv"))
write_csv(collect("fom"), file.path(d, "summary_fom_forest_built.csv"))
write_csv(collect("timing"), file.path(d, "summary_timing.csv"))

cat("ensemble golden written to", d, "\n")
