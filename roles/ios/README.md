# iOS development environment

Owner: the dotfiles `ios` role. Run `dotfiles -t ios` to install what builds, signs, and installs
iOS apps from this machine without a Mac: xtool, the Darwin Swift SDK, and the device tools. The
role is opt-in and absent from `default_roles`: its first run compiles for about 15 minutes.
Only Ubuntu 24.04 x86_64 is supported, and the `swift` role must have installed
`swift_toolchain_version` first. Any other state fails before installation.

The work is done by [omarchy-apple-dev](https://github.com/joshuaswarren/omarchy-apple-dev)'s
`install-toolchain.sh` in full mode, at a pinned commit. That project targets Arch; this role
supplies what Ubuntu and swiftly need around it.

## Installation contract

Inputs are `host_user`, `host_user_home`, `swift_toolchain_version`, and the `ios_*` values in
`group_vars/all.yml`. One input cannot be automated: the Xcode archive.

1. Run `dotfiles -t ios`. It installs everything except the SDK and reports `iOS SDK pending`.
2. Sign in at https://developer.apple.com/download/all/?q=Xcode with a free Apple ID and download
   the Xcode `.xip` named by `ios_xcode_major` (27 for Swift 6.4). The SDK's Swift must match the
   toolchain's. Save it as `ios_xcode_xip` (default `~/Downloads/Xcode.xip`).
3. Run `dotfiles -t ios` again. It extracts the SDK, registers it, and stops reporting it pending.

Verify with `swift sdk list`, which prints `darwin`. The archive can be deleted afterwards: the
extracted SDK is kept in `~/.cache/xtool/`.

Outputs under the host user's home:

- `.local/lib/ios-dev/imobiledevice-<id>/`: libplist, libimobiledevice-glue, libtatsu, and
  libimobiledevice, built from the pinned commits. `<id>` is derived from those four commits.
- `.cache/ios-dev/src/`: their source checkouts.
- `.local/share/omarchy-apple-dev/`: the installer's checkout, with `device-run.sh` and `ship.sh`.
- `.local/bin/xtool`, `rcodesign`, `ipsw`; `.local/lib/omarchy-apple-dev/xtool-<commit>/`.
- `pymobile3-venv/`: pymobiledevice3 at the pinned version.
- `.swiftpm/swift-sdks/darwin.artifactbundle` and `.cache/xtool/`: the Darwin SDK.
- `.config/omarchy-apple-dev/mode` and `.local/state/ios-dev/installed-<commit>-swift-<version>`.

The installer also edits three build-setting defaults inside the swiftly toolchain's
`usr/share/pm/` so string resources build on Linux.

## Why it differs from the upstream instructions

- **Private libimobiledevice.** Ubuntu's 1.3.0 cannot build xtool. Upstream installs the newer
  stack system-wide through `ld.so.conf.d`, which would also replace the libraries the packaged
  `usbmuxd` daemon loads. Here the stack lives in a private prefix with its own run path, and its
  libraries are linked into xtool's directory, the only place xtool searches before system paths.
- **Real toolchain first on `PATH`.** The installer locates the toolchain by resolving `swift`.
  Swiftly's `swift` is a proxy, so the role puts `ios_swift_bin` first while it runs.
- **Pinned pymobiledevice3.** The installer takes the latest release; the role installs the
  pinned one first, which the installer then leaves alone.
- **Full mode only.** Packages needed only for Flutter or the no-Xcode mode are not installed.

## Repeat runs, updates, and failures

Until the SDK is registered every run calls the installer, which skips what it already built.
Once registered, the marker file skips the installer and a repeat run changes nothing.

To update, change the pinned value and rerun. A new `ios_toolchain_ref` or
`swift_toolchain_version` selects a new marker, so the installer runs again; with a new Swift
version also download the matching Xcode and set `ios_xcode_major`. A new libimobiledevice commit
selects a new prefix and rebuilds all four libraries; old prefixes are left in place. After
reinstalling the same Swift version, delete the marker and rerun.

Invalid platform, pins, or a missing toolchain fail before package installation. Package, fetch,
build, and installer errors fail the playbook; an installer status of 1 counts as success only
with its `One download left` message. Completed steps are not rolled back; rerun after resolving
the error. The role does not edit shell profiles: `~/.local/bin` must already be on `PATH`.

## After installation

These steps are interactive and belong to the user, not the role:

```sh
xtool auth                 # Apple ID sign-in, needed before device installs
xtool new Hello && cd Hello
xtool dev build            # builds xtool/Hello.app for arm64 iOS
~/.local/share/omarchy-apple-dev/device-run.sh   # with the iPhone on USB and trusted
```

## Verification status

The role's branching is covered by `tests/test_ios_role.py`, which uses fake sources and a fake
installer. As of 2026-10-12 the role has not been run for real on this machine: the library
builds, the xtool build against swiftly, and SDK extraction are unverified until the first
`dotfiles -t ios`. Upstream verified Ubuntu 24.04 in a container in its no-Xcode mode only.

```sh
/usr/bin/python3 -m unittest discover -s tests -p test_ios_role.py -v
```
