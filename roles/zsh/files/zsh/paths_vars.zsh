#!/usr/bin/env zsh

# Add custom bin directories
addToPath "$HOME/.dotfiles/bin"
addToPath "$HOME/.local/bin"

# Add Nix to PATH if available
sourceIfExists "/etc/profile.d/nix.sh"

# # Add op plugins NOT UNTIL WE FIGURE OUT RDS
# sourceIfExists "$HOME/.config/op/plugins.sh"

# Add independently install binaries to PATH

addToPath "$HOME/.opencode/bin"

## Add nix-installed binaries to PATH
# Volta setup
if [ -d "$HOME/.volta" ]; then
    export VOLTA_HOME="$HOME/.volta"
    addToPathFront "$VOLTA_HOME/bin"
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

# Mise setup
if command -v mise &>/dev/null; then
    eval "$(~/.local/bin/mise activate zsh)"
fi


# Optional tooling setup (e.g., Aactivator)
if command -v aactivator &>/dev/null; then
    eval "$(aactivator init)"
fi
