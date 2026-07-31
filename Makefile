.DEFAULT_GOAL := help

.PHONY: help bootstrap privacy check manuscript-check reproduce-results

help:
	@echo "Common targets: bootstrap, privacy, check, manuscript-check, reproduce-results."

bootstrap:
	Rscript scripts/run.R bootstrap

privacy:
	Rscript scripts/run.R privacy --strict-history

manuscript-check:
	Rscript scripts/run.R manuscript-check

reproduce-results:
	Rscript scripts/run.R reproduce-results --check

check:
	Rscript scripts/run.R privacy --strict-history
	Rscript scripts/run.R reproduce-results --check
	Rscript scripts/run.R manuscript-check
