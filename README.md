# Automatic and zero-effort development environments with Nix

This repo collects my forbidden techniques for setting up development environments with Nix and Direnv. It is a work in progress and will be updated as I learn more.

## Nix and Direnv setup script

[scripts/install_nix.sh](scripts/install_nix.sh) is a script that sets up a Nix development environment with Direnv.

It installs Nix and Direnv, installs a much faster (caching) use_flake implementation and configures the shell configuration. It uses the [Determinate systems Nix installer](https://determinate.systems/posts/determinate-nix-installer/) which is a popular installer that sets some sane defaults, like enabling flake support.

I recommend copying this file into your repo and updating your README instructions to include running it first thing.

## More coming soon
