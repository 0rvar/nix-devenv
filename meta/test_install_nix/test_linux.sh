#!/usr/bin/env bash

set -euo pipefail

# Create a temporary directory for the test
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Copy install_nix.sh and flake files to the test directory
cp "$(dirname "$0")/../../scripts/install_nix.sh" "$TEST_DIR/"
cp "$(dirname "$0")/flake-test/flake.nix" "$TEST_DIR/"
cp "$(dirname "$0")/flake-test/.envrc" "$TEST_DIR/"

# Build the test image
podman build -t nix-test-env "$(dirname "$0")"

# Run docker with the prepared image
podman run -it --rm \
  --privileged \
  -v "$TEST_DIR:/workspace" \
  -w /workspace \
  nix-test-env \
  /bin/bash -c '
    su tester -c "
      cd /workspace && \
      source ./install_nix.sh && \
      direnv allow && \
      which rg | grep -q \"/nix/store/\" || (echo \"ERROR: rg not found in /nix/store\" && exit 1) && \
      echo \"SUCCESS: Test passed - direnv environment activated and tools available from /nix/store\"
    "
  '
# /bin/bash -c 'exec su tester'
