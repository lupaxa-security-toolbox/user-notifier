# PAM / install shell suite used by `make check`.
.PHONY: shell-test

# No installable package under src/; type-check tests via pyproject only.
MYPY_ARGS :=

shell-test:
	@bash tests/run_all.sh
