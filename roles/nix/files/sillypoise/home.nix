{ config, pkgs, ... }:

{
    # Required state version for compatibility
    home.stateVersion = "24.05";  # Adjust according to your Home Manager release

    # Define the username for the Home Manager configuration
    home.username = "sillypoise";
    home.homeDirectory = "/home/sillypoise";

    # Package Management
        home.packages = with pkgs; [
      (python312.withPackages (ps: [
        ps.datasette
        ps.setuptools
      ]))
      aws-vault                  # AWS credential management
      awscli2                    # AWS CLI
      bat                        # Improved cat with syntax highlighting
      biome                      # Linting and formatting toolchain
      btop                       # Resource monitor
      broot                      # Enhanced directory navigation
      # datasette                  # Publish and explore SQLite databases
      # python312Packages.setuptools  # Required for datasette (pkg_resources)
      delta                      # Git diff viewer with syntax highlighting
      dysk                       # df alternative
      eza                        # Enhanced ls with better formatting
      fd                         # Simple and fast file search
      fzf                        # Command-line fuzzy finder
      httpie                     # Command-line HTTP client
      gh                         # GitHub CLI
      git                        # Version control system
      gnused                     # GNU sed (stream editor)
      jq                         # JSON processor
      k9s                        # k8s tui
      lazydocker                 # Simplified Docker management
      lazygit                    # Simplified Git UI
      neofetch                   # Modern fetch
      neovim                     # Modern text editor
      podman                     # Docker alternative: manage pods, containers and container images
      postgresql_17              # PostgreSQL 17
      ripgrep                    # Fast, recursive file search
      rsync                      # File synchronization utility
      rustup                     # Rust toolchain installer
      sd                         # Modern sed alternative
      sqlite-utils               # SQLite utility and CLI
      starship                   # Customizable shell prompt
      # tailscale                # Mesh VPN service
      tree-sitter                # Syntax parsing tool for editors
      volta                      # JavaScript tool manager
      zellij                     # Terminal workspace manager
      zoxide                     # Directory navigation tool
      zsh                        # Z shell (command-line interpreter)
    ];
}
