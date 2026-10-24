# Deterministic golden: the paper's model set-up with the randomness
# removed, exported stage by stage so each stage of a reimplementation can
# be checked on its own:
#
#   train_cells.csv        cells of the 10% training partition (seed fixed)
#   glm_coefficients.csv   fitted binary logistic regressions
#   probabilities.csv.gz   predicted suitability per cell and category, the
#                          exact matrix allocate() works on (before elasticity)
#   demand.csv             approxExtrapDemand(obs, 0:14), after roundSum
#   clues_maps.tif         CLUE-S, jitter.f = 0 (15 bands, t0..t14)
#   ordered_maps.tif       ordered allocation, stochastic = FALSE
#   <model>_tables.csv, _agreement.csv, _fom.csv   validation at t14
#   timing.csv
#
# Given probabilities.csv.gz and demand.csv, a correct CLUE-S or ordered
# allocation must reproduce the maps cell by cell (up to exact ties).

source("scripts/common.R")

SEED <- as.integer(Sys.getenv("DETERMINISTIC_SEED", "1"))
d <- out_dir("deterministic")
p <- load_pie()
obs <- p$obs
ef <- p$ef

set.seed(SEED)
part <- partition(x = obs[[1]], size = 0.1, spatial = TRUE)
train_cells <- cells_of(obs[[1]], part[["train"]])
write_csv(data.frame(cell = sort(train_cells)), file.path(d, "train_cells.csv"))

train.data <- getPredictiveModelInputData(obs = obs, ef = ef, cells = part[["train"]])
glm.models <- glmModels(formula = FORMS, family = binomial, data = train.data, obs = obs)
write_csv(glm_coefficients(glm.models), file.path(d, "glm_coefficients.csv"))

# Same cells and the same call as allocate() (R/allocate.R, CluesModel method).
cells <- which(!is.na(raster::getValues(obs[[1]])))
newdata <- as.data.frame(x = ef, cells = cells)
prob <- predict(object = glm.models, newdata = newdata)
prob <- as.data.frame(prob)
names(prob) <- glm.models@labels
write_csv(cbind(data.frame(cell = cells,
                           lu_t0 = raster::extract(obs[[1]], cells)), prob),
          file.path(d, "probabilities.csv.gz"))

dmd <- approxExtrapDemand(obs = obs, tout = 0:14)
dmd_df <- as.data.frame(dmd)
names(dmd_df) <- obs@labels
write_csv(cbind(data.frame(t = 0:14), dmd_df), file.path(d, "demand.csv"))

rules <- matrix(data = 1, nrow = 3, ncol = 3, byrow = TRUE)
params <- CLUES_PARAMS
params$jitter.f <- 0

clues.model <- CluesModel(obs = obs, ef = ef, models = glm.models,
                          time = 0:14, demand = dmd, elas = CLUES_ELAS,
                          rules = rules, params = params)
ordered.model <- OrderedModel(obs = obs, ef = ef, models = glm.models,
                              time = 0:14, demand = dmd, order = ORDERED_ORDER)

tc <- timed(allocate(clues.model))
clues.model <- tc$value
to <- timed(allocate(ordered.model, stochastic = FALSE))
ordered.model <- to$value

write_maps(clues.model@output, file.path(d, "clues_maps.tif"))
write_maps(ordered.model@output, file.path(d, "ordered_maps.tif"))
validate_model(clues.model, d, "clues")
validate_model(ordered.model, d, "ordered")

write_csv(data.frame(seed = SEED, step = c("clues", "ordered"),
                     seconds = c(tc$seconds, to$seconds)),
          file.path(d, "timing.csv"))

cat("deterministic golden written to", d, "\n")
