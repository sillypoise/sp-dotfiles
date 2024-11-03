#!/usr/bin/env zsh

# Add custom bin directories
addToPath "$HOME/.dotfiles/bin"
addToPath "$HOME/.local/bin"

# Add Nix to PATH if available
sourceIfExists "/etc/profile.d/nix.sh"

# Volta setup
if [ -d "$HOME/.volta" ]; then
    export VOLTA_HOME="$HOME/.volta"
    addToPathFront "$VOLTA_HOME/bin"
fi

# Github Copilot CLI Prompt setup
if command -v github-copilot-cli &>/dev/null; then
    eval "$(github-copilot-cli alias -- "$0")"
fi

# Rustup setup
if command -v rustup &>/dev/null; then
    addToPath "$HOME/.cargo/bin"
fi

# Starship Prompt setup
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide setup
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# Optional tooling setup (e.g., Aactivator)
if command -v aactivator &>/dev/null; then
    eval "$(aactivator init)"
fi
