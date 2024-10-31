#!/usr/bin/env zsh

addToPath $HOME/.dotfiles/bin

sourceIfExists "/nix/var/nix/profiles/default"
