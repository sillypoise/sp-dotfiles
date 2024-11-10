#!/usr/bin/env bash

# Add custom bin directories
addToPath "$HOME/.dotfiles/bin"
addToPath "$HOME/.local/bin"

# Add Nix to PATH if available
sourceIfExists "/etc/profile.d/nix.sh"
