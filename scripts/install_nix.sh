#!/usr/bin/env bash

set -euo pipefail

REQUIRE_RESTART=false

NIX_INSTALLED=$(command -v nix || true)
if [ -z "$NIX_INSTALLED" ]; then
  echo "Nix is not installed. Installing..."
  echo
  echo "Note: the installer will ask for your password to install nix."
  echo
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  echo "[√] Nix installed"
  echo

  # Try to source nix profile
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    REQUIRE_RESTART=true
  else
    echo "ERROR: Nix profile not found. Please restart your terminal and run this script again."
    exit 1
  fi
fi

if ! command -v nix >/dev/null; then
  echo "ERROR: Nix commands not available in current shell session."
  echo "Please restart your terminal and run this script again."
  exit 1
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

shell_name=$(basename $SHELL)
if [ "$shell_name" = "fish" ]; then
  echo "IMPORTANT: install the direnv plugin for fish"
elif [ "$shell_name" = "bash" ]; then
  touch ~/.bashrc
  # Check if .bashrc already has the line
  grep -q "eval \"\$(direnv hook bash)\"" ~/.bashrc ||
    (
      echo "Adding direnv hook to ~/.bashrc" &&
        echo "eval \"\$(direnv hook bash)\"" >>~/.bashrc &&
        REQUIRE_RESTART=true
    )
elif [ "$shell_name" = "zsh" ]; then
  touch ~/.zshrc
  # Check if .zshrc already has the line
  grep -q "eval \"\$(direnv hook zsh)\"" ~/.zshrc ||
    (
      echo "Adding direnv hook to ~/.zshrc" &&
        echo "eval \"\$(direnv hook zsh)\"" >>~/.zshrc &&
        REQUIRE_RESTART=true
    )
else
  echo "IMPORTANT: Add the direnv hook to your shell profile manually:"
  echo "https://direnv.net/docs/hook.html"
  echo "Then restart your terminal session"
fi

if [ "$REQUIRE_RESTART" = true ]; then
  echo
  echo
  echo " =========== IMPORTANT ===================== "
  echo " Restart your terminal to use nix and direnv "
  echo " =========================================== "
  echo
  echo

  # Provide instructions for manual sourcing as an alternative to restarting
  echo "Alternatively, you can run these commands in your current shell to load without restart:"
  echo
  echo "For Nix:"
  echo "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  echo
  echo "For direnv (based on your shell):"
  if [ "$shell_name" = "bash" ]; then
    echo "  eval \"\$(direnv hook bash)\""
  elif [ "$shell_name" = "zsh" ]; then
    echo "  eval \"\$(direnv hook zsh)\""
  elif [ "$shell_name" = "fish" ]; then
    echo "  direnv hook fish | source"
  fi
fi
