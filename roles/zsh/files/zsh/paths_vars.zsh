#!/usr/bin/env zsh

addToPath $HOME/.dotfiles/bin
addToPath $HOME/.local/bin

sourceIfExists "/etc/profile.d/nix.sh"
