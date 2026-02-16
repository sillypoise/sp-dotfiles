# sillypoise dotfiles

Supported OS:
- Arch Linux
- Ubuntu LTS (starter-level support)

## Usage

### Install

This playbook includes a custom shell script located at `bin/dotfiles`. After the first run, it is
available as `dotfiles` via `/usr/local/bin` and can be run multiple times while making sure any
Ansible dependencies are installed and updated.

`bin/dotfiles` detects the distro and installs the required dependencies for Arch or Ubuntu.

On the first run, `bin/dotfiles` automatically runs the `bootstrap` role (as root) when no tags
are provided.

This shell script is also used to initialize your environment after bootstrapping your
`supported-OS` and performing a full system upgrade as mentioned above.

> [!NOTE]
> You must follow required steps before running this command or things may become unusable until
> fixed.

```bash
bash -c "$(
  curl -fsSL https://raw.githubusercontent.com/sillypoise/sp-dotfiles/main/bin/dotfiles || \
  wget -qO- https://raw.githubusercontent.com/sillypoise/sp-dotfiles/main/bin/dotfiles
)"
```

For headless installs using a 1Password service account token:
```bash
OP_SERVICE_ACCOUNT_TOKEN=... bash -c "$(
  curl -fsSL https://raw.githubusercontent.com/sillypoise/sp-dotfiles/main/bin/dotfiles || \
  wget -qO- https://raw.githubusercontent.com/sillypoise/sp-dotfiles/main/bin/dotfiles
)"
```

On first run, use a short-lived service account token. The long-term token is injected via
`vars.secret` and takes effect on the next run.

If you want to run only a specific role, you can specify the following bash command:
```bash
curl -fsSL https://raw.githubusercontent.com/sillypoise/sp-dotfiles/main/bin/dotfiles | \
  bash -s -- -u root -t bootstrap
```

### Update

This repository is continuously updated with new features and settings which become available to
you when updating.

To update your environment run the `dotfiles` command in your shell:

```bash
dotfiles
```

This will handle the following tasks:

- Verify Ansible is up-to-date
- Clone this repository locally to `/opt/dotfiles`
- Verify any `ansible-galaxy` plugins are updated
- Run this playbook with the values in `group_vars/all.yml`

This `dotfiles` command is available after the first run via `/usr/local/bin/dotfiles`, allowing
you to call `dotfiles` from anywhere.

Any flags or arguments you pass to the `dotfiles` command are passed as-is to the
`ansible-playbook` command.

For Example: Running the tmux tag with verbosity
```bash
dotfiles -t tmux -vvv
```

As an added bonus, the tags have tab completion!
```bash
dotfiles -t <tab><tab>
dotfiles -t t<tab>
dotfiles -t ne<tab>
```

## OpenCode Guides

This repository does not own OpenCode guide content.
Guide families are maintained in the dedicated guides repository and cloned to
the user environment by the `opencode` role.

Guide-family authoring and governance should happen in the dedicated guides repository.
This repo focuses on environment replication and distribution plumbing.

To install OpenCode and clone the shared guides repository into your environment, run:

```bash
dotfiles -t opencode
```

To initialize a project repo with a local overlay, run:

```bash
opencode-init-repo
```

`opencode-init-repo` creates a repo-root `AGENTS.md` from the shared guides template and writes a
repo-local `opencode.json` that loads both:

- shared guides selector (`~/.local/share/opencode-guides/files/AGENTS.md`)
- repo-local overlay (`AGENTS.md`)

Then edit `AGENTS.md` to add repo-specific context and optional guide additions from the shared
guides `VARIANTS.md`.
