{ config, pkgs, ... }:

{
    # Required state version for compatibility
    home.stateVersion = "24.05";  # Adjust according to your Home Manager release

    # Package Management
    home.packages = with pkgs; [
        neovim
        ripgrep
        fzf
        bat
        broot
        fd
        eza
        gnused
        sd
        lazygit
        lazydocker
        jq
        tree-sitter
        starship
        btop
        gh
        tailscale
        git
        zellij
        sqlite-utils
        datasette
        rustup
        rsync
        awscli2
        aws-vault
        delta
        volta
        zoxide
    ];
}

