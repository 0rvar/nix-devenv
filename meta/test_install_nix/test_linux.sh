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

tests() {
  shell=$1
  if [[ $shell = "fish" ]]; then
    echo "
        direnv allow
        eval (direnv export $shell) # No hook in non-interactive shell
        # Check that rg is available and lives in /nix/store
        if not command -v rg >/dev/null 2>&1
          echo \"Error: rg command not found\"
          exit 1
        end
        
        set RG_PATH (which rg)
        if test \$RG_PATH != /nix/store/*
          echo \"Error: rg is not from nix store: \$RG_PATH\"
          exit 1
        end
        
        echo \"Success: rg found in nix store at \$RG_PATH\"
        
        # Verify the flake environment variable is set
        if test -z \$HELLO_FROM_FLAKE
          echo \"Error: HELLO_FROM_FLAKE environment variable not set\"
          exit 1
        end
        
        echo \"Success: HELLO_FROM_FLAKE=\$HELLO_FROM_FLAKE\"
    "
  else
    echo "
        set -e
        direnv allow
        eval \"\$(direnv export $shell)\" # No hook in non-interactive shell
        # Check that rg is available and lives in /nix/store
        if ! command -v rg >/dev/null 2>&1; then
          echo \"Error: rg command not found\"
          exit 1
        fi
        
        RG_PATH=\$(which rg)
        if [[ \$RG_PATH != /nix/store/* ]]; then
          echo \"Error: rg is not from nix store: \$RG_PATH\"
          exit 1
        fi
        
        echo \"Success: rg found in nix store at \$RG_PATH\"
        
        # Verify the flake environment variable is set
        if [[ -z \${HELLO_FROM_FLAKE:-} ]]; then
          echo \"Error: HELLO_FROM_FLAKE environment variable not set\"
          exit 1
        fi
        
        echo \"Success: HELLO_FROM_FLAKE=\$HELLO_FROM_FLAKE\"
    "
  fi
}

run_with_shell() {
  local shell=$1
  echo "Running test with $shell"
  if ! podman run -it --rm \
    --privileged \
    -v "$TEST_DIR:/workspace" \
    -w /workspace \
    nix-test-env \
    /bin/bash -c "
      set -e
      sudo chsh -s \$(which $shell)
      export SHELL=\$(which $shell)
      cd /workspace
      
      # Install nix and direnv first
      $shell -il -c 'NIX_INSTALLER_ARGS=\"install linux --init none --no-confirm\" ./install_nix.sh'
      
      # Run the actual tests
      $shell -il -c '$(tests $shell)'
    "; then
    echo "Test failed with $shell"
    return 1
  fi
}

# Run tests and exit with failure if any test fails
if ! run_with_shell zsh; then
  exit 1
fi

if ! run_with_shell bash; then
  exit 1
fi

if ! run_with_shell fish; then
  exit 1
fi

echo "All tests passed!"
