{ config, pkgs, ... }:

{
    # Required state version for compatibility
    home.stateVersion = "24.05";  # Adjust according to your Home Manager release

    # Define the username for the Home Manager configuration
    home.username = "sillypoise";
    home.homeDirectory = "/home/sillypoise";

    # Allow unfree packages (needed for claude-code)
    nixpkgs.config.allowUnfree = true;

    # Package Management
        home.packages = with pkgs; [
      (python312.withPackages (ps: [
        ps.datasette
        ps.llm
        ps.setuptools
        ps.sqlite-utils
        ps.ruff
        ps.uv
      ]))
      aws-vault                  # AWS credential management
      awscli2                    # AWS CLI
      bat                        # Improved cat with syntax highlighting
      biome                      # Linting and formatting toolchain
      broot                      # Enhanced directory navigation
      btop                       # Resource monitor
      bun                        # JavaScript runtime and package manager
      claude-code                # Agentic coding tool from Anthropic
      codex                      # Lightweight coding agent that runs in your terminal
      # datasette                  # Publish and explore SQLite databases
      delta                      # Git diff viewer with syntax highlighting
      deno                       # JavaScript runtime
      duf                        # df alternative
      eza                        # Enhanced ls with better formatting
      fd                         # Simple and fast file search
      fzf                        # Command-line fuzzy finder
      gh                         # GitHub CLI
      git                        # Version control system
      gnused                     # GNU sed (stream editor)
      go                         # Go programming language
      httpie                     # Command-line HTTP client
      jq                         # JSON processor
      k9s                        # k8s tui
      lazydocker                 # Simplified Docker management
      lazygit                    # Simplified Git UI
      mise
      neofetch                   # Modern fetch
      neovim                     # Modern text editor
      ngrok                      # local revers proxy
      opencode                   # AI coding agent built for the terminal
      pnpm                       # Fast, disk space efficient package manager
      podman                     # Docker alternative: manage pods, containers and container images
      postgresql_17              # PostgreSQL 17
      # python312Packages.setuptools  # Required for datasette (pkg_resources)
      ripgrep                    # Fast, recursive file search
      rsync                      # File synchronization utility
      rustup                     # Rust toolchain installer
      sd                         # Modern sed alternative
      # sqlite-utils               # SQLite utility and CLI
      starship                   # Customizable shell prompt
      # tailscale                # Mesh VPN service
      tree-sitter                # Syntax parsing tool for editors
      volta                      # JavaScript tool manager
      zellij                     # Terminal workspace manager
      zoxide                     # Directory navigation tool
      zsh                        # Z shell (command-line interpreter)
    ];
}
