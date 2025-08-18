[private]
default:
    just --list

# Run integration tests for the snap
[group("test")]
integration:
	sh tests/integration/test_integration.sh