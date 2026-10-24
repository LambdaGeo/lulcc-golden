# lulcc-goldens

Reference outputs ("goldens") of the R package **lulcc 1.0.4** for the
Plum Island Ecosystems application in

> Moulds, S., Buytaert, W., & Mijic, A. (2015). An open and extensible
> framework for spatially explicit land use change modelling: the lulcc R
> package. *Geoscientific Model Development*, 8, 3215–3229.
> https://doi.org/10.5194/gmd-8-3215-2015

The goldens are generated with the original code (the package's
`demo/gmd-paper.R`) in a fixed Docker environment. They are the reference
for an independent Python replication; this repository contains no
reimplementation.

**Status:** skeleton. The goldens have not been generated yet in the Docker
environment. The scripts were run once outside it (R 4.3.3 and raster
3.6-26 from Ubuntu 24.04, lulcc 1.0.4 from source) as a smoke test; see
"Smoke test" below.

## Why two kinds of golden

The paper sets no random seed, and three steps draw random numbers: the
10% training partition, the CLUE-S jitter (`jitter.f = 0.0002`) and the
stochastic ordered allocation. Its numbers (AUCs in Figs. 5–6, agreement
budget and figure of merit in Figs. 7–8) are therefore one draw of a
distribution, and cannot be repeated exactly, not even with lulcc itself.

| Golden | What it fixes | How a replication is compared |
|---|---|---|
| `deterministic/` | One partition (seed 1), `jitter.f = 0`, `stochastic = FALSE`; every stage exported | Stage by stage: glm coefficients (tolerance), allocation **cell by cell** given the exported probabilities and demand |
| `ensemble/` | The demo as published, one run per seed (default 30) | By distribution: AUCs and figure of merit against the spread of the seeds, with criteria written before the comparison |
| `data/` | The `pie` data set as GeoTIFF and the observed transition tables | Exactly (the paper's cross-tabulation, Sect. 3.2) |

## Layout

```
goldens/
├── data/                 pie layers (GeoTIFF), layers.csv, crosstab.csv
├── deterministic/        train_cells, glm_coefficients, probabilities.csv.gz,
│                         demand, clues_maps.tif, ordered_maps.tif,
│                         *_tables/_agreement/_fom.csv, timing
├── ensemble/
│   ├── seed_001/ …       auc, auc_builtgain, glm_coefficients, maps,
│   │                     *_tables/_agreement/_fom.csv, timing
│   └── summary_*.csv     AUCs, figure of merit (forest → built), timing
├── environment.json      R, RNG, package versions and build dates
├── sessionInfo.txt
├── image_id.txt
└── SHA256SUMS
```

Maps are multiband GeoTIFFs, band 1 = t0 (1985) to band 15 = t14 (1999),
codes 1 Forest, 2 Built, 3 Other, nodata 255. `*_tables.csv` are the
three-map contingency tables of `ThreeMapComparison` (factors 2 to 256),
from which every validation number of the paper is derived.

## Generate

Requires Docker and `make`.

```bash
make image              # build the R environment
make quick              # data + deterministic + 2 seeds, a few minutes
make check-determinism  # deterministic golden again, byte for byte
make goldens            # full set: 30 seeds, about 45 min
make verify             # check SHA256SUMS
```

`SEEDS=50 make ensemble` changes the number of seeds.

## The demo does not run unchanged on current R

The `pie` rasters were serialized by an old version of the raster package,
before the `srs` slot (WKT2 CRS) existed. With current raster/sp,
`allocate()` creates the simulated map with `raster::raster(map0)`, which
has a WKT2 CRS, while the old object has none; it then stops with
`Error in compareRaster(x) : different crs` when stacking the two.
`scripts/common.R` (`refresh_crs`) rebuilds each layer as a fresh
RasterLayer with the same grid, CRS and values, and checks that values,
extent and resolution are unchanged. (Re-assigning the CRS with `crs<-`
does not work on the old objects: it leaves them with no CRS at all.) The
rebuilt layers carry the CRS, which GDAL identifies as EPSG:26986 (NAD83 /
Massachusetts Mainland). Each run writes `goldens/crs_refreshed.txt`. This
is the only change to the published demo.

## Smoke test (outside Docker, 24 Oct 2026)

- The observed transitions 1985 → 1999 match Sect. 3.2 of the paper
  exactly (e.g. 44107 forest cells persist, 4250 become built).
- The deterministic golden is identical byte for byte across two runs.
- AUCs of the glm models, paper vs seeds 1 and 2: forest 0.6423 vs
  0.6443 / 0.6442; built 0.9384 vs 0.9382 / 0.9385; other 0.7276 vs
  0.7302 / 0.7285; gain of built 1985–1991 (Fig. 6) 0.6448 vs 0.6448 /
  0.6449.
- Time: about 90 s per seed (most of it random forest fitting); CLUE-S
  about 10 s, ordered allocation about 1 s.

## Notes for the replication

- `deterministic/probabilities.csv.gz` is the matrix `allocate()` works on
  (from `predict()` on all valid cells), before elasticity is added. The
  CLUE-S of lulcc then adds `elas` to the current class, applies the
  transition rules and iterates in `src/allocateclues.c`.
- In `allocateclues.c` the second stopping condition uses the *signed*
  mean of the differences between demand and allocation. When demand rows
  sum to the number of cells (as after `roundSum`), that mean is about
  zero, so in practice only `max.diff` stops the iteration.
- `fom@transition[[f]][i, j]` and the `from`/`to` columns of `*_fom.csv`
  are the transition from category `i` to `j`; Figs. 7–8 show Forest →
  Built.
- `randomForestModels()` receives a 0/1 numeric response, so random forest
  runs in regression mode (randomForest warns about it). This is lulcc's
  behaviour and is kept; it only affects the rf AUCs of Fig. 5.
- The pixels of `pie` are not square (99.92 m × 99.95 m).
- CSV files write doubles with 17 significant digits (R's `write.csv` keeps
  15), so values round-trip exactly to float64.
- lulcc 1.0.4 was packaged in 2019 and republished on CRAN in November
  2025 under the same version number. `environment.json` records the
  `Packaged` and `Date/Publication` fields of the build actually used.

## Licence

Scripts: MIT (see `LICENSE`). lulcc and its `pie` data set: see
`THIRD_PARTY.md`.
