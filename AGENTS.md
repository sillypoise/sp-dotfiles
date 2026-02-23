# Repo-Local AGENTS Overlay

<!-- BEGIN MANAGED OVERLAY -->
Do not edit this managed block directly. Use `opencode-sync-repo --write` to update it from the
shared template.

Overlay-Template-Version: 0.1.1
Overlay-Template-Hash: 646ce926fbe1275e002ef90674b2bbb53b801cae33409ba975c1700dcdbdd519
Guide-Bundle-Version: 0.3.1
Guide-Bundle-Source-Ref: v0.3.1

This file is a repo-local overlay for project-specific instructions.
It supplements the shared guide bundle and should only contain context that is specific to this
repository.

Do not include secrets, credentials, or tokens.

## Guide Layering Contract

This overlay extends and complements (does not replace) the shared guide policy loaded from
`files/AGENTS.md`.

The shared policy is the primary behavioral instruction source. This overlay adds repository-specific
constraints, context, workflows, and optional active-guide additions.

Agents MUST apply both layers together:

1. Follow shared policy as baseline behavior.
2. Apply repo-specific constraints from this overlay in addition to shared policy.

When guidance appears to conflict, preserve shared mandatory requirements and treat overlay guidance
as project-specific augmentation that narrows or clarifies behavior for this repository.

## Mandatory Guide Compliance Loop

For non-trivial tasks, the agent MUST:

1. Identify which active guides apply before implementation.
2. Apply active guide rules during implementation and self-review.
3. In the final response, include a rule-application trace with concrete references:
   - Rule ID (or section heading if no stable ID),
   - where applied (`path:line`),
   - one short note on how it shaped the change.
4. Explicitly verify negative/error/boundary paths, not only happy paths.
5. If a rule is intentionally not applied, state why and mark it as a project-level exception.
6. If active guides do not cover the task domain, suggest 1-2 minimal guide additions from
   `VARIANTS.md`.

When guidance conflicts, follow canonical precedence from the guide system.

## Response Prefix Contract

For implementation tasks, start the final response with:

`Guide check: active guides applied.`
<!-- END MANAGED OVERLAY -->

## Optional Active-Guide Additions

Add project-specific guides here when needed (for example, language or framework guides from
`VARIANTS.md`). Keep defaults high-signal and only add guides required by this repo.

Example:

- `go/tigerstyle-go-strict-full.md`
- `nextjs/nextjs-strict-full.md`

<!-- BEGIN LOCAL GUIDE ADDITIONS -->
<!-- END LOCAL GUIDE ADDITIONS -->

## Repo-Specific Context

Use concise, factual notes for architecture, workflows, constraints, and release expectations.

When durable repo facts are learned during work, update this section to keep it current.
Only include stable information that helps future tasks.

<!-- BEGIN REPO CONTEXT -->

### Repository Purpose

This repository is an Ansible-based dotfiles system focused on environment replication and
distribution plumbing.

This repository does not own shared OpenCode guide-family content. Guide authoring,
derivation, and governance happen in the dedicated guides repository.

### OpenCode Integration Workflow

Run `dotfiles -t opencode` to install OpenCode and clone shared guides into the local user
environment.

To initialize a repo-local overlay, run `opencode-init-repo` (alias: `oci`). It creates
repo-root `AGENTS.md` from the shared template and writes repo-local `opencode.json` that
loads shared guides plus repo-local context.

To refresh only the managed scaffold section of repo `AGENTS.md` while preserving
repo-specific context, use `opencode-sync-repo` (dry-run by default, `--write` to apply).

### Build, Test, Validation

Main execution commands:

- `dotfiles` (full configuration update)
- `dotfiles -t <role>` (run specific role)
- `dotfiles -u <user> -t <tag>` (specific user and tag)
- `dotfiles -t <role> -vvv` (debug verbosity)

Validation commands:

- `dotfiles -t <role>` (role-level validation)
- `dotfiles -t test` (dedicated validation role)
- `op whoami` (verify 1Password CLI auth)

Linting policy:

- No automated linting is configured (`ansible-lint`/`yamllint` absent).
- Manual validation is done by running roles through `dotfiles`.

### Style and Authoring Conventions

YAML:

- 2-space indentation, no tabs.
- Keep lines under 120 characters where practical.
- Use a single blank line to separate logical blocks.
- Avoid trailing whitespace.

Ansible module/task conventions:

- Use fully qualified module names (for example `ansible.builtin.copy`).
- Prefer idempotent modules over shell commands.
- If shell is required, preserve idempotency (`creates:` or `changed_when: false` as
  appropriate).
- Set `executable: /bin/bash` when bash features are used.
- Every task should have tags.
- Pre-tasks use the `always` tag.

Naming:

- Roles: lowercase descriptive names, hyphenated as needed, under `roles/<role>/`.
- Variables: lowercase with underscores (for example `host_user`).
- Facts: `facts_` prefix (for example `facts_is_arch`).
- Define defaults in `group_vars/all.yml`.

Imports/includes:

- Prefer `ansible.builtin.import_tasks` for static includes.
- Use `ansible.builtin.include_role` for role orchestration.

### Security and Secrets

Secret handling:

- Templates containing `op://` references use `.tpl`.
- Inject secrets with `op inject`.
- Never commit real secrets; only commit templates.
- Use `no_log: true` for secret operations.
- Service account bootstrap: set `OP_SERVICE_ACCOUNT_TOKEN` for first run, then re-run
  after `vars.secret` injects the long-term token.

File permissions:

- Secrets: `0600`.
- Config files: `0644`.
- Directories: `0755`.
- Scripts: `0755`.

### Architecture and Platform Notes

Core files:

- `main.yml` orchestrates role execution.
- `bin/dotfiles` bootstraps/updates and runs the playbook.
- `group_vars/all.yml` holds default roles and global variables.
- `pre_tasks/facts.yml` handles fact gathering and detection.

Distro support:

- Supported: Arch Linux and Ubuntu LTS (starter-level support).
- `bin/dotfiles` detects distro and installs base dependencies.
- First run with no tags executes the `bootstrap` role as root.
- Use `facts_is_arch` and `facts_is_ubuntu` for OS-specific branching.
- Use `sudo_group` for sudo membership (`wheel` on Arch, `sudo` on Ubuntu).

Role structure:

- `roles/<role>/tasks/main.yml`
- optional `roles/<role>/files/`
- optional `roles/<role>/templates/`

Template conventions:

- Jinja templates use `.j2`.
- Secret templates use `.tpl` with 1Password injection.

Role order:

- Role execution follows `default_roles` in `group_vars/all.yml`.
- Keep dependency order in mind when reordering roles.

### Development Workflow Expectations

Adding a role:

1. Create `roles/<role>/tasks/main.yml`.
2. Add role to `default_roles` in `group_vars/all.yml`.
3. Add variables to `group_vars/all.yml` if needed.
4. Add `files/` or `templates/` as required.
5. Tag tasks appropriately.
6. Test with `dotfiles -t <role>`.

Idempotency and safe execution:

- Use `creates:` to avoid re-running installation commands.
- Use `changed_when: false` for read-only commands.
- Guard tasks with `when:` facts to ensure safe execution.

Root-run safety:

- First-run executes as root; avoid root-owned files in user homes.
- Any task writing into a user home must set `owner`/`group` or run with `become_user`.
- Shell/command tasks that depend on user env or write under user home should use
  `become_user`.

### Additional Repo Fact

No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` are present in
this repository.

<!-- END REPO CONTEXT -->
