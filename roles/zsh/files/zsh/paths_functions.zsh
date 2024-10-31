#!/usr/bin/env zsh

addToPath() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$PATH:$1
    fi
}

addToPathFront() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$1:$PATH
    fi
}

sourceIfExists() {
    local path="$1"
    if [ -e "$path" ]; then
        . "$path"
        echo "Sourced $path"
    else
        echo "Warning: $path not found, skipping."
    fi
}

# change_background() {
#     dconf write /org/mate/desktop/background/picture-filename "'$HOME/anime/$(ls ~/anime| fzf)'"
# }

die () {
    echo >&2 "$@"
    exit 1
}

