# Swift development environment

Owner: the dotfiles `swift` role. Run `dotfiles -t swift` to install the Ubuntu prerequisites,
Swiftly, and the official Swift toolchain outside Nix. The role is also in `default_roles`.
Only Ubuntu 24.04 x86_64 is supported. Unsupported default runs skip Swift with a message;
explicit `dotfiles -t swift` requests fail before installation. Adding support
requires reviewing that platform's dependencies and pinning its installer checksum.

## Installation contract

Inputs are `host_user`, `host_user_home`, and the exact versions and SHA-256 in
`group_vars/all.yml`. Swiftly's archive comes from `download.swift.org` over HTTPS and is checked
against the committed digest before extraction. Swiftly verifies Swift's PGP signature.
The pinned Swift version was checked against https://www.swift.org/api/v1/install/releases.json.
To update Swiftly, review the official release and change both its version and checksum.
To update Swift, change `swift_toolchain_version` and rerun the role.

Outputs under the host user's home:

- `.local/share/swiftly/`: manager, toolchains, environment, and binary proxies.
- `.cache/swiftly/<version>/`: retained verified installer for repeat runs.
- `.config/bash/zz-swift.bash` and `.config/zsh/zz-swift.zsh`: load Swiftly after other PATH setup.

The first toolchain becomes the default. Later runs install the pinned version if absent but
preserve the user's default selection. Select another default with
`swiftly use <version> --global-default`. The role does not delete existing toolchains, rewrite
shell profiles, or run automatic upgrades. Restart the shell, or run:

```sh
. "$HOME/.local/share/swiftly/env.sh"
swift --version
```

Invalid platform/version/checksum inputs fail before package installation. Download, checksum,
initialization, toolchain installation, and executable check errors fail the playbook. Completed
apt operations or an initialized manager are not rolled back; rerun after resolving the error.
Shell snippets are written only after successful toolchain installation. On a previously
configured machine, failures preserve existing snippets and toolchains rather than removing them.
This is additive to existing dotfiles; there is no migration or deprecation of Nix configuration.
A fresh toolchain needs a large download and several GB of disk; repeat runs do not redownload
an already-installed toolchain. No application libraries are installed globally.

## Editor and smoke test

The separate `~/.config/nvim` repository configures `sourcekit` with Mason disabled and uses
`~/.local/share/swiftly/bin/sourcekit-lsp`. Its proxy works without a login-shell PATH and follows
Swiftly's selected toolchain. Commit/push that repository separately to replicate the editor setup.
SwiftPM builds supply the project's index; run `swift build` in the package root.

Use a scratch directory, not an existing project:

```sh
scratch=$(mktemp -d)
(cd "$scratch" && swift package init --type library && swift build && swift test)
rm -rf "$scratch"
```

Role tests (fake package/toolchain operations, real checksum and file operations):

```sh
/usr/bin/python3 -m unittest discover -s tests -p test_swift_role.py -v
```

Linux networking, Combine alternatives, and cancellation semantics belong to application design,
not host provisioning. Verify streaming behavior against the chosen toolchain before selecting
an HTTP client; any such library should be a project-level SwiftPM dependency.
