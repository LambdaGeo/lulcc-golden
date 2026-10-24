IMAGE      ?= lulcc-goldens:dev
SEEDS      ?= 30
FIRST_SEED ?= 1
GOLDENS    ?= goldens

RUN = docker run --rm -v "$(CURDIR)":/work -w /work \
      -u $$(id -u):$$(id -g) -e HOME=/tmp -e GOLDENS_DIR=$(GOLDENS) $(IMAGE)

.PHONY: help image pin data deterministic ensemble environment checksums \
        goldens quick verify check-determinism clean

help:
	@echo "make image              build the R environment (Docker)"
	@echo "make pin                print the digest of the base image"
	@echo "make quick              data + deterministic + 2 seeds (~5 min)"
	@echo "make goldens            data + deterministic + $(SEEDS) seeds + checksums (~45 min for 30 seeds)"
	@echo "make check-determinism  run the deterministic golden again and compare"
	@echo "make verify             check goldens/SHA256SUMS"

image:
	docker build -t $(IMAGE) .

pin:
	@docker pull -q $$(sed -n 's/^ARG BASE_IMAGE=//p' Dockerfile) >/dev/null
	@docker inspect --format='{{index .RepoDigests 0}}' $$(sed -n 's/^ARG BASE_IMAGE=//p' Dockerfile)

data:
	$(RUN) Rscript scripts/export_pie.R

deterministic:
	$(RUN) Rscript scripts/deterministic.R

ensemble:
	$(RUN) Rscript scripts/ensemble.R $(SEEDS) $(FIRST_SEED)

environment:
	$(RUN) Rscript scripts/manifest.R
	docker image inspect --format='{{.Id}}' $(IMAGE) > $(GOLDENS)/image_id.txt

checksums:
	cd $(GOLDENS) && find . -type f ! -name SHA256SUMS | LC_ALL=C sort | xargs sha256sum > SHA256SUMS

goldens: data deterministic ensemble environment checksums

quick:
	$(MAKE) data deterministic environment
	$(MAKE) ensemble SEEDS=2 GOLDENS=$(GOLDENS)

verify:
	cd $(GOLDENS) && sha256sum -c --quiet SHA256SUMS && echo "OK: all checksums match"

# Runs the deterministic golden into a scratch folder and compares every
# file byte for byte with goldens/deterministic.
check-determinism:
	rm -rf .check && mkdir -p .check
	docker run --rm -v "$(CURDIR)":/work -w /work -u $$(id -u):$$(id -g) \
	  -e HOME=/tmp -e GOLDENS_DIR=.check $(IMAGE) Rscript scripts/deterministic.R
	@fail=0; for f in $$(cd $(GOLDENS)/deterministic && ls); do \
	  case $$f in timing.csv) continue;; esac; \
	  if cmp -s $(GOLDENS)/deterministic/$$f .check/deterministic/$$f; then echo "same  $$f"; \
	  else echo "DIFF  $$f"; fail=1; fi; done; rm -rf .check; exit $$fail

clean:
	rm -rf .check
