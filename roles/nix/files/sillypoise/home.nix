{ config, pkgs, ... }:

{
    # Required state version for compatibility
    home.stateVersion = "24.05";  # Adjust according to your Home Manager release

    # Define the username for the Home Manager configuration
    home.username = "sillypoise";
    home.homeDirectory = "/home/sillypoise";

    # Package Management
    home.packages = with pkgs; [
        aws-vault
        awscli2
        bat
        btop
        broot
        datasette
        delta
        eza
        fd
        fzf
        gh
        git
        gnused
        jq
        lazydocker
        lazygit
        neovim
        ripgrep
        rsync
        rustup
        sd
        sqlite-utils
        starship
        tailscale
        tree-sitter
        ufw
        volta
        zellij
        zoxide
        zsh
    ];
}

