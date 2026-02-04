# AGENTS.md

This file provides guidance for AI coding agents working in this Ansible
dotfiles repository.

## Build, Test, and Lint Commands

### Main Commands
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

### Test and Validation
```bash
# Test a specific role
dotfiles -t <role>

# Test the dedicated validation role
dotfiles -t test

# Verify 1Password CLI authentication
op whoami
```

### Linting
- No automated linting is configured (no ansible-lint or yamllint).
- Manual validation is expected by running roles via the dotfiles script.

## Code Style Guidelines

### YAML Formatting
- Indentation: 2 spaces, no tabs.
- Keep lines under 120 characters where practical.
- Use a single blank line to separate logical blocks.
- Avoid trailing whitespace.

### Ansible Module Usage
- Always use fully qualified module names, e.g. `ansible.builtin.copy`.
- Prefer idempotent modules over shell commands.
- If a shell command is required, ensure idempotency with `creates:` or
  `changed_when: false` when appropriate.
- Provide `executable: /bin/bash` when the shell relies on bash features.

### Task Structure
```yaml
- name: Descriptive task name
  ansible.builtin.module:
    key: value
  become: true
  become_user: "{{ host_user }}"
  when: facts_sillypoise_exists
  changed_when: false
  no_log: true
  tags:
    - tag_name
```

### Naming Conventions

#### Roles
- Lowercase, descriptive names: `bash`, `git`, `nvim`, `openssh`.
- Use hyphens for multi-word names.
- Create roles under `roles/<role>/`.

#### Tasks
- Use descriptive names, often with a pipe separator.
- Examples: `Debug | Show current Ansible user`,
  `system setup | nix | install home-manager`.

#### Variables and Facts
- Variables: lowercase with underscores (`host_user`, `automated_user`).
- Facts: `facts_` prefix (`facts_nix_installed`, `facts_zsh_config_installed`).
- Define defaults in `group_vars/all.yml`.

#### Tags
- Every task should have tags.
- Common tags: `environment`, `config`, `secrets`, `bootstrap`, `system`.
- Use the role name as a tag when it fits.
- Pre-tasks use the `always` tag.

### Imports and Includes
- Prefer `ansible.builtin.import_tasks` for static includes.
- Use `ansible.builtin.include_role` for role orchestration.

## Security and Secrets

### Secret Handling
- Use `.tpl` for templates that contain `op://` references.
- Inject secrets with `op inject`.
- Never commit real secrets; only commit templates.
- Use `no_log: true` for secret operations.

### File Permissions
- Secrets: `0600`.
- Config files: `0644`.
- Directories: `0755`.
- Scripts: `0755`.

## Repository Architecture

### Core Files
- `main.yml`: orchestrates role execution.
- `bin/dotfiles`: bootstrap/update script that runs the playbook.
- `group_vars/all.yml`: default roles and global variables.
- `pre_tasks/facts.yml`: fact gathering and detection.

### Distro Support
- Supported: Arch Linux and Ubuntu LTS (starter-level support).
- `bin/dotfiles` detects the distro and installs base dependencies.
- Use `facts_is_arch` and `facts_is_ubuntu` for OS-specific branches.
- Use `sudo_group` for sudo membership (`wheel` on Arch, `sudo` on Ubuntu).

### Role Structure
```
roles/<role>/
  tasks/main.yml
  files/
  templates/
```

### Templates
- Jinja2 templates use `.j2`.
- Secret templates use `.tpl` and are injected via 1Password CLI.

## Development Workflow

### Adding a Role
1. Create `roles/<role>/tasks/main.yml`.
2. Add role to `default_roles` in `group_vars/all.yml`.
3. Add variables to `group_vars/all.yml` if needed.
4. Add `files/` or `templates/` as required.
5. Tag tasks appropriately.
6. Test with `dotfiles -t <role>`.

### Error Handling and Idempotency
- Use `creates:` to avoid re-running installation commands.
- Use `changed_when: false` for read-only commands.
- Guard tasks with `when:` facts to ensure safe execution.

## Cursor/Copilot Rules
- No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md`
  were found in this repository.
