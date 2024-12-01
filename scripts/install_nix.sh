#!/usr/bin/env bash

set -euo pipefail

DID_CHANGE_ENV=false

NIX_INSTALLED=$(command -v nix || true)
if [ -z "$NIX_INSTALLED" ]; then
  echo "Nix is not installed. Installing..."
  echo
  echo "Note: the installer may ask for your password to install nix."
  echo

  INSTALL_FLAGS=(${NIX_INSTALLER_ARGS:-"install --no-confirm"})

  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- ${INSTALL_FLAGS[@]}
  echo "[√] Nix installed"
  echo
  DID_CHANGE_ENV=true

  # Try to source nix profile - needed for the rest of the script
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  else
    echo "ERROR: Nix profile not found. Please restart your terminal and run this script again."
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

shell_name=$(basename "$SHELL")
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
        DID_CHANGE_ENV=true
    )
elif [ "$shell_name" = "zsh" ]; then
  touch ~/.zshrc
  # Check if .zshrc already has the line
  grep -q "eval \"\$(direnv hook zsh)\"" ~/.zshrc ||
    (
      echo "Adding direnv hook to ~/.zshrc" &&
        echo "eval \"\$(direnv hook zsh)\"" >>~/.zshrc &&
        DID_CHANGE_ENV=true
    )
else
  echo "IMPORTANT: Add the direnv hook to your shell ($shell_name) profile manually:"
  echo "https://direnv.net/docs/hook.html"
  echo "Then restart your terminal session"
  exit 0
fi

if [[ "$DID_CHANGE_ENV" = "true" ]]; then
  echo
  echo
  echo " =========== IMPORTANT ===================== "
  echo " Restart your terminal to use nix and direnv "
  echo " =========================================== "
  echo
  echo
  exit 0
else
  echo "Everything up to date, nothing to do"
fi
