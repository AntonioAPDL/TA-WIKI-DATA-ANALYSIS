.DEFAULT_GOAL := help

.PHONY: help bootstrap check test privacy verify hooks readiness intake validate transform analyze qualitative qualitative-snapshot release verify-release manuscript-preview manuscript-attested-build coauthor-brief

help:
	@echo "Optional wrappers for the canonical Rscript scripts/run.R interface."
	@echo "Common targets: bootstrap, readiness, privacy, check (or test), verify, manuscript-preview, manuscript-attested-build, coauthor-brief."

bootstrap:
	Rscript scripts/run.R bootstrap

check:
	Rscript scripts/run.R test

test: check

privacy:
	Rscript scripts/run.R privacy $(ARGS)

verify:
	Rscript scripts/run.R privacy --strict-history
	Rscript scripts/run.R test

hooks:
	git config core.hooksPath .githooks

readiness:
	Rscript scripts/run.R readiness

intake validate transform analyze qualitative qualitative-snapshot release verify-release:
	Rscript scripts/run.R $@ $(ARGS)

manuscript-preview manuscript-attested-build:
	Rscript scripts/run.R $@ $(ARGS)

coauthor-brief:
	Rscript scripts/run.R coauthor-brief $(ARGS)
