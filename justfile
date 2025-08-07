[private]
default:
    just --list

# Run integration tests for the snap
[group("test")]
integration:
	sh tests/integration/test_integration.sh
	
# Shellcheck all shell scripts in the project
[group("test")]
shellcheck:
	docker run --rm -v './:/mnt' -it koalaman/shellcheck tests/integration/test_integration.sh \
	    snap/hooks/configure \
	    snap/hooks/install \
	    snap/local/command-wrapper 