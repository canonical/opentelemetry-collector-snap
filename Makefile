PROJECT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TESTS := $(PROJECT)tests
ALL := $(SRC) $(TESTS)

export PYTHONPATH = $(PROJECT)
export PY_COLORS=1

# Run integration tests
integration:
	sh tests/integration/test_integration.sh