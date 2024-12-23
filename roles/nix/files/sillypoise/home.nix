{ config, pkgs, ... }:

{
    # Required state version for compatibility
    home.stateVersion = "24.05";  # Adjust according to your Home Manager release

    # Define the username for the Home Manager configuration
    home.username = "sillypoise";
    home.homeDirectory = "/home/sillypoise";

    # Package Management
    home.packages = with pkgs; [
        aws-vault            # AWS credential management
        awscli2              # AWS CLI
        bat                  # Improved cat with syntax highlighting
        btop                 # Resource monitor
        broot                # Enhanced directory navigation
        datasette            # Publish and explore SQLite databases
        delta                # Git diff viewer with syntax highlighting
        eza                  # Enhanced ls with better formatting
        fd                   # Simple and fast file search
        fzf                  # Command-line fuzzy finder
        gh                   # GitHub CLI
        git                  # Version control system
        gnused               # GNU sed (stream editor)
        jq                   # JSON processor
        lazydocker           # Simplified Docker management
        lazygit              # Simplified Git UI
        neovim               # Modern text editor
        ripgrep              # Fast, recursive file search
        rsync                # File synchronization utility
        rustup               # Rust toolchain installer
        sd                   # Modern sed alternative
        sqlite-utils         # SQLite utility and CLI
        starship             # Customizable shell prompt
        # tailscale          # Mesh VPN service
        tree-sitter          # Syntax parsing tool for editors
        volta                # JavaScript tool manager
        zellij               # Terminal workspace manager
        zoxide               # Directory navigation tool
        zsh                  # Z shell (command-line interpreter)
    ];
}
