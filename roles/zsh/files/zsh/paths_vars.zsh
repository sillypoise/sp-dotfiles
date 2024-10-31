#!/usr/bin/env zsh

addToPath $HOME/.dotfiles/bin

sourceIfExists "$HOME/.nix-profile/etc/profile.d/nix.sh"
