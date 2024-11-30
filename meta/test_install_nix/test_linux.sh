#!/usr/bin/env bash

set -euo pipefail

# Create a temporary directory for the test
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Copy install_nix.sh to the test directory
cp "$(dirname "$0")/../../scripts/install_nix.sh" "$TEST_DIR/"

# Build the test image
docker build -t nix-test-env "$(dirname "$0")"

# Run docker with the prepared image
docker run -it --rm \
  --privileged \
  -v "$TEST_DIR:/workspace" \
  -w /workspace \
  nix-test-env \
  /bin/bash -c 'exec su tester'
