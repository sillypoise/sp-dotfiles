# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository that uses Ansible to manage system configurations across Arch Linux machines. The repository automates the setup and maintenance of development environments through role-based configuration management.

## Key Commands

### Dotfiles Management
```bash
# Run full configuration update
dotfiles

# Run specific role (with tab completion support)
dotfiles -t <role>

# Run as specific user with specific tags
dotfiles -u <user> -t <tag>

# Debug mode with verbose output
dotfiles -t <role> -vvv
```

### Testing Changes
```bash
# Test a specific role
dotfiles -t test

# Verify 1Password CLI authentication
op whoami
```

## Architecture

### Core Structure
- **main.yml**: Orchestrates all role executions in proper order
- **bin/dotfiles**: Main script that handles installation, updates, and Ansible playbook execution
- **roles/**: Contains individual configuration roles (bash, git, nvim, etc.)
- **group_vars/all.yml**: Defines default roles and global variables

### Security & Secrets
- Uses 1Password CLI for secure credential management
- Template files (`.tpl`) require 1Password authentication to populate secrets
- SSH keys and sensitive configs are managed through 1Password integration

### User Management
- Primary user: `sillypoise` (host user with full permissions)
- Automation user: `flubber` (default for dotfiles operations)
- Both users have separate SSH configurations and keys

### Key Ansible Roles
- **bootstrap**: Initial system setup (excluded from default runs)
- **nix**: Package management with Home Manager
- **zsh/bash**: Shell configurations
- **nvim**: Neovim setup
- **git**: Version control configuration
- **ssh/openssh**: SSH client and server configs
- **tailscale**: Mesh VPN setup
- **ufw**: Firewall rules

## Development Guidelines

### Adding New Roles
1. Create role directory under `roles/`
2. Add to `default_roles` in `group_vars/all.yml`
3. Include tasks in `roles/<role>/tasks/main.yml`
4. Use templates with `.j2` extension for dynamic configs

### Working with Templates
- Templates requiring secrets should use `.tpl` extension
- Access 1Password items via `op://` references in templates
- Always verify 1Password authentication before running sensitive roles

### Testing Modifications
- Test individual roles with `-t <role>` flag
- Use `-vvv` for debugging Ansible execution
- Check `~/.config/dotfiles/group_vars/all.yaml` for local overrides

### Common Patterns
- Use `become: true` for tasks requiring sudo
- Tag tasks appropriately for selective execution
- Follow existing role structure for consistency
- Keep idempotency in mind - tasks should be safe to run multiple times