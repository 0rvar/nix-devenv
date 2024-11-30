#!/usr/bin/env bash

shell_name=$(basename $SHELL)
IS_SOURCED=false

# Determine if script can/should be sourced
if [[ "$shell_name" != "fish" ]]; then
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script must be sourced. Please run:"
    echo "  source ${0}"
    exit 1
  fi
  IS_SOURCED=true
fi

set -euo pipefail

DID_CHANGE_ENV=false

NIX_INSTALLED=$(command -v nix || true)
if [ -z "$NIX_INSTALLED" ]; then
  echo "Nix is not installed. Installing..."
  echo
  echo "Note: the installer will ask for your password to install nix."
  echo
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  echo "[√] Nix installed"
  echo
  DID_CHANGE_ENV=true

  # Try to source nix profile - needed for the rest of the script
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  else
    echo "ERROR: Nix profile not found. Please restart your terminal and run this script again."
    if [ "$IS_SOURCED" = true ]; then
      return 1
    else
      exit 1
    fi
  fi
fi

if ! command -v nix >/dev/null; then
  echo "ERROR: Nix commands not available in current shell session."
  echo "Please restart your terminal and run this script again."
  if [ "$IS_SOURCED" = true ]; then
    return 1
  else
    exit 1
  fi
fi

NIX_PROFILE_LIST=$(nix profile list)
nix_pkg_ensure_installed() {
  package=$1
  if ! echo "$NIX_PROFILE_LIST" | sed -r "s/\x1b\[[0-9;]*m//g" | grep -qE "^Name:\W+$package\$"; then
    echo "Installing $package"
    nix profile install "nixpkgs#$package"
  fi
}

nix_pkg_ensure_installed direnv
# Faster use_flake implementation with caching
nix_pkg_ensure_installed nix-direnv

# Update config
mkdir -p ~/.config/direnv

# Configure direnv to use nix-direnv for use_flake - it's much faster
touch ~/.config/direnv/direnvrc
grep -q "source \$HOME/.nix-profile/share/nix-direnv/direnvrc" ~/.config/direnv/direnvrc || (
  echo "Adding nix-direnv to ~/.config/direnv/direnvrc" &&
    echo 'source $HOME/.nix-profile/share/nix-direnv/direnvrc' >>~/.config/direnv/direnvrc
)

# Configure direnv to suppress diff output - it's just noise
touch ~/.config/direnv/direnv.toml
grep -q "hide_env_diff = true" ~/.config/direnv/direnv.toml || (
  echo "Updating ~/.config/direnv/direnv.toml" &&
    echo "[global]" >>~/.config/direnv/direnv.toml &&
    echo "hide_env_diff = true" >>~/.config/direnv/direnv.toml
)

if [ "$shell_name" = "fish" ]; then
  if ! fish -c "functions -q __direnv_export_eval" >/dev/null; then
    echo "Adding direnv hook to fish shell (~/.config/fish/conf.d/direnv.fish)"
    # Add to ~/.config/fish/conf.d/direnv.fish
    mkdir -p ~/.config/fish/conf.d
    touch ~/.config/fish/conf.d/direnv.fish
    grep -q "direnv hook fish | source" ~/.config/fish/conf.d/direnv.fish ||
      (
        echo "direnv hook fish | source" >>~/.config/fish/conf.d/direnv.fish &&
          DID_CHANGE_ENV=true
      )
  fi
elif [ "$shell_name" = "bash" ]; then
  touch ~/.bashrc
  # Check if .bashrc already has the line
  grep -q "eval \"\$(direnv hook bash)\"" ~/.bashrc ||
    (
      echo "Adding direnv hook to ~/.bashrc" &&
        echo "eval \"\$(direnv hook bash)\"" >>~/.bashrc &&
        eval "$(direnv hook bash)" && # Immediately enable direnv
        DID_CHANGE_ENV=true
    )
elif [ "$shell_name" = "zsh" ]; then
  touch ~/.zshrc
  # Check if .zshrc already has the line
  grep -q "eval \"\$(direnv hook zsh)\"" ~/.zshrc ||
    (
      echo "Adding direnv hook to ~/.zshrc" &&
        echo "eval \"\$(direnv hook zsh)\"" >>~/.zshrc &&
        eval "$(direnv hook zsh)" && # Immediately enable direnv
        DID_CHANGE_ENV=true
    )
else
  echo "IMPORTANT: Add the direnv hook to your shell profile manually:"
  echo "https://direnv.net/docs/hook.html"
  echo "Then restart your terminal session"
  if [ "$IS_SOURCED" = true ]; then
    return 1
  else
    exit 1
  fi
fi

REQUIRE_RESTART=false
if [[ $DID_CHANGE_ENV = true ]] && [[ ! $IS_SOURCED ]]; then
  REQUIRE_RESTART=true
fi

if [ "$REQUIRE_RESTART" = true ]; then
  echo
  echo
  echo " =========== IMPORTANT ===================== "
  echo " Restart your terminal to use nix and direnv "
  echo " =========================================== "
  echo
  echo
fi
