# Playbook: iOS development from a Linux machine

How to take a fresh Ubuntu 24.04 machine to building, signing, and installing iOS apps on an
iPhone, with no Xcode running anywhere. Written on 2026-10-12 from the first setup, on a remote
machine reached over SSH. `roles/ios/README.md` is the role's contract; this file is the whole
procedure around it.

## What has been proven

Every step below is marked. Trust the marks, not the prose.

| Stage | Status on 2026-10-12 |
|---|---|
| Toolchain install through the role | **Verified** on Ubuntu 24.04 x86_64 |
| Darwin SDK from an Xcode archive | **Verified** with Xcode 27.1 RC and Swift 6.4.0 |
| Build an iOS app, including one that uses a SwiftPM library | **Verified** (`xtool dev build`, arm64) |
| Device tools on Python 3.13 | Role change written and unit-tested; **not yet applied** to a machine |
| Sign with an App Store Connect API key | **Untested** |
| Reach the phone through the Mac's USB port over SSH | **Untested**; the parts were checked separately |
| Install and launch over Tailscale | **Untested** here; upstream measured it on iOS 27.0.1 |
| TestFlight upload | **Untested** here; upstream has done it |
| macOS apps | **Untested**; one attempt failed on project configuration before compiling |

Update this table as stages are proven.

## What you get and what you do not

- **iOS apps:** yes, including extensions and widgets.
- **macOS apps:** buildable, signable, and notarizable per upstream; they cannot run on Linux, so
  testing needs a Mac.
- **watchOS, tvOS, visionOS:** no. The SDK holds only the iPhone, iPhone Simulator, and Mac
  platforms.
- **Simulator:** none on Linux. Testing means a real iPhone.

## Why this much machinery

Apple ships the whole pipeline inside Xcode, which runs only on macOS. Xcode does five jobs, and
on Linux each needs its own replacement.

| Job | What Linux lacks | What fills it |
|---|---|---|
| Compile | Apple's SDK: the definitions of SwiftUI, UIKit, and Foundation for iOS, found only inside Xcode | The open-source Swift toolchain already emits iPhone code; `xtool sdk` cuts the SDK out of an Xcode `.xip` |
| Compile | Apple's macro plugins (`#Preview` and others), shipped as Mac binaries | OpenAppleMacros, a reimplementation the installer builds |
| Bundle | Xcode's project system and its asset, string, and interface compilers | `xtool dev build` turns a SwiftPM package into a `.app`; the installer adds Linux stand-ins for the resource compilers |
| Sign | Xcode's link to Apple's developer services | `xtool` with an Apple ID, or `provision-dev.py` and `sign-dev.sh` with an API key; `rcodesign` does the signing |
| Install, launch, debug | Xcode's device connection | `usbmuxd` and libimobiledevice for USB; pymobiledevice3 for tunnels, install, launch, logs; `lldb` from the Swift toolchain |
| Ship | Xcode's upload | `ship.sh` |

Who owns what:

- **`swift` role:** the compiler, through swiftly.
- **[omarchy-apple-dev](https://github.com/joshuaswarren/omarchy-apple-dev):** the installer and
  scripts that assemble the table above, plus fixes for where Linux differs. Written for Arch.
- **`ios` role:** the adaptation to Ubuntu and swiftly, and the version pins. It runs that
  installer unmodified at a pinned commit.
- **Your app:** an ordinary SwiftPM package with an `xtool.yml`.

## What you need

- Ubuntu 24.04 x86_64 with these dotfiles, and about 16 GB of free disk (the first setup used 14 GB,
  plus 2 GB for the Xcode archive).
- An Apple ID. Free is enough to download Xcode.
- For a remote machine or TestFlight: the paid Apple Developer Program (US$99 a year). Enrol as
  an individual unless you have a registered company; Apple can convert it later.
- An iPhone on iOS 27 with Tailscale, on the same tailnet as the build machine. iOS 26 blocks
  the cable-free route.
- Any computer with a browser for the Xcode download, and one you can plug the phone into once.
  A Mac serves for both and needs nothing installed.

## Part A: the environment

**Verified.** About 25 minutes, mostly unattended.

1. Install the toolchains the role depends on:

   ```sh
   dotfiles -t swift
   dotfiles -t nix        # provides ~/.nix-profile/bin/python3.13 for the device tools
   ```

2. Run the role. It builds everything except the SDK and ends with `iOS SDK pending`:

   ```sh
   dotfiles -t ios
   ```

3. Download Xcode in a browser, on any computer: sign in at
   https://developer.apple.com/download/all/?q=Xcode and take the Xcode `.xip` whose Swift
   matches the toolchain: Xcode 27 for Swift 6.4, Xcode 26 for Swift 6.3. Do not open the file.
   Xcode 27.1 RC worked with Swift 6.4.0.

4. Copy it to the build machine under the name the role expects:

   ```sh
   ssh sp-dev 'mkdir -p ~/Downloads'
   rsync -P ~/Downloads/Xcode_27.xip sp-dev:Downloads/Xcode.xip
   ```

5. Run the role again. It extracts and registers the SDK:

   ```sh
   dotfiles -t ios
   swift sdk list         # prints: darwin
   ```

The archive can then be deleted; the extracted SDK stays in `~/.cache/xtool/`.

What went wrong the first time, all handled by the role now:

- Ubuntu's libimobiledevice is too old to build xtool, so four libraries are built from pinned
  commits into a private prefix.
- The installer finds the toolchain by resolving `swift`, which under swiftly is a proxy. The
  role puts the real toolchain directory first on `PATH`.
- xtool's archive reader needs `liblzma-dev` and `zlib1g-dev`.
- Ubuntu's Python 3.12 cannot open the iPhone tunnel; the device tools run on Python 3.13.

## Part B: build an app

**Verified.**

```sh
xtool new MyApp --skip-setup
cd MyApp
xtool dev build          # writes xtool/MyApp.app, arm64 iOS, unsigned
```

- The project is a SwiftPM package with one library product, plus `xtool.yml` holding the bundle
  identifier. Add dependencies in `Package.swift` as usual, including local ones by path.
- Use `xtool dev build`, not `swift build --swift-sdk arm64-apple-ios`: with Swift 6.4 the plain
  SwiftPM route fails with `unable to find platform for 'iphoneos'`.
- Logic that does not touch Apple frameworks can be tested on Linux with `swift test`, with none
  of this involved.
- A worked example is `Examples/Probe` in the `pi-durable-swift` repository.
- If a build reports `Too many open files`, run `ulimit -n 65536` first.

## Part C: the Apple account and signing

**Untested.** The commands come from upstream's scripts.

An iPhone runs only apps signed by a certificate Apple issued, with a profile that names the app
and the device. There are two ways to get them.

**Free Apple ID.** `xtool dev run` creates the certificate and profile and registers the phone,
but only with the phone attached to the build machine. Builds stop opening after 7 days. On a
remote machine this works only through the forwarded USB socket in Part D.

**Paid program, with an API key.** Works with no phone attached, which a remote machine needs.

1. Enrol at https://developer.apple.com/programs/enroll/.
2. In App Store Connect, under Users and Access > Integrations, create a team API key with the
   App Manager role. Download the `.p8` file once and note the Key ID and Issuer ID.
3. Put the key on the build machine, readable only by you:

   ```sh
   mkdir -p ~/.appstoreconnect/private_keys && chmod 700 ~/.appstoreconnect
   # copy AuthKey_XXXXXXXXXX.p8 there, then:
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
   export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
   export ASC_KEY_ID=XXXXXXXXXX
   export ASC_ISSUER_ID=<issuer uuid>
   ```

   Never commit the key or these values.

4. Create the development certificate, register the phone, and create the profile. The UDID
   comes from Part D:

   ```sh
   T=~/.local/share/omarchy-apple-dev/tools
   ~/pymobile3-venv/bin/python $T/provision-dev.py --bundle-id com.example.myapp --udid <UDID> --name my-phone
   ```

   Run it with the venv's Python as shown: the `python3` on `PATH` lacks the `cryptography`
   module. Output goes to `~/.config/omarchy-apple-dev/development/`.

5. Sign a build:

   ```sh
   $T/sign-dev.sh xtool/MyApp.app MyApp-dev.ipa
   ```

## Part D: reach the phone

**Untested as a whole.** The USB library on the build machine accepts a forwarded socket, and
the SSH server allows the forwarding; those two facts were checked.

The phone must be cabled to something once, to trust the build machine. On a remote machine,
borrow a nearby computer's USB port over SSH. On a Mac nothing needs installing.

1. Cable the iPhone to the Mac, unlock it, and tap Trust.
2. On the Mac, forward its device socket and leave the second command running:

   ```sh
   ssh sp-dev 'rm -f ~/usbmuxd.sock'
   ssh -N -R /home/sillypoise/usbmuxd.sock:/var/run/usbmuxd sp-dev
   ```

   The first command matters: the server will not replace a socket left by an earlier session.

3. On the build machine, point the tools at that socket and read the phone's UDID:

   ```sh
   export USBMUXD_SOCKET_ADDRESS=UNIX:$HOME/usbmuxd.sock    # xtool and libimobiledevice
   export PYMOBILEDEVICE3_USBMUX=$HOME/usbmuxd.sock         # pymobiledevice3
   ~/pymobile3-venv/bin/pymobiledevice3 usbmux list
   ```

4. Turn on Developer Mode, which iOS requires before it runs development builds. The phone
   restarts and asks for confirmation:

   ```sh
   ~/pymobile3-venv/bin/pymobiledevice3 amfi enable-developer-mode
   ```

   If that is refused, install any development build first; the switch then appears under
   Settings > Privacy & Security > Developer Mode.

5. Pair for cable-free use. This writes `~/.local/share/pymobiledevice3/remote_<udid>.plist`,
   which holds a private key; treat it like an SSH key:

   ```sh
   ~/pymobile3-venv/bin/python ~/.local/share/omarchy-apple-dev/tools/tailnet-tunnel.py pair
   ```

6. While the cable is in, an install can go straight through it:

   ```sh
   ~/pymobile3-venv/bin/pymobiledevice3 apps install MyApp-dev.ipa
   ```

   With a free Apple ID, `xtool dev run` in the project directory does build, sign, register,
   and install in one step through the same socket.

After step 5 the cable and the forwarding are no longer needed.

## Part E: the daily loop

**Untested** beyond the build.

```sh
swift test                                   # logic, on Linux
xtool dev build                              # iOS build
$T/sign-dev.sh xtool/MyApp.app MyApp-dev.ipa
tailscale status                             # the phone's 100.x address
~/.local/share/omarchy-apple-dev/device-run.sh --over-tailnet 100.x.y.z MyApp-dev.ipa
```

The last command needs sudo for the tunnel device. It installs, launches, and closes the tunnel.
Add `--console 30` to print the app's output for 30 seconds.

The phone must be on Wi-Fi with Tailscale connected, and unlocked once since its last restart.
On cellular alone the phone refuses the connection.

To look at a running phone, open a tunnel and use the address it prints:

```sh
~/pymobile3-venv/bin/python $T/tailnet-tunnel.py 100.x.y.z --hold 600    # prints: RSD <addr> <port>
~/pymobile3-venv/bin/pymobiledevice3 developer dvt screenshot shot.png --rsd <addr> <port>
~/pymobile3-venv/bin/pymobiledevice3 syslog live --rsd <addr> <port>
```

## Part F: TestFlight

**Untested here.** Paid program only.

1. In App Store Connect, create the app record with your bundle identifier. The API cannot.
2. From the project directory, with the three `ASC_` variables set:

   ```sh
   ~/.local/share/omarchy-apple-dev/ship.sh --upload
   ```

   It builds a release app, creates the distribution certificate and profile on first use, signs,
   validates offline, and uploads. It never submits for review.

Because the SDK came from a `.xip`, `ship.sh` may need `XCODE_VERSION` and `XCODE_BUILD` set to
stamp the build; its header explains them.

## Part G: a Mac app

**Untested.** Upstream's `ship-mac.sh` builds, signs, and notarizes a SwiftPM executable; see
section 5 of `~/.local/share/omarchy-apple-dev/GETTING-STARTED.md`. Building an iOS-style xtool
project with `--triple arm64-apple-macosx` failed here on a deployment-target mismatch.

## Known gaps

- **Mixed USB libraries.** xtool loads Ubuntu's `libusbmuxd` beside the private, newer
  `libplist`. With no phone it showed no fault. If xtool misbehaves on USB, build `libusbmuxd`
  from source into the private prefix; note that its current source changes the library's
  version name, so xtool would need rebuilding against it.
- **Upstream scripts and swiftly.** `ship.sh` and `device-run.sh` also resolve `swift` to find
  the toolchain. If one cannot find `clang` or `lldb`, put the real toolchain first:
  `export PATH=~/.local/share/swiftly/toolchains/6.4.0/usr/bin:$PATH`.
- **One author.** omarchy-apple-dev and its forks of xtool and OpenAppleMacros belong to one
  person. The role pins commits; copies of all three are in `~/.local/share/omarchy-apple-dev`
  and `~/.cache/omarchy-apple-dev` on any machine the role has run on.
- **Toolchain edits.** The installer patches three files inside the swiftly toolchain.
  Reinstalling the same Swift version loses them: delete the marker in
  `~/.local/state/ios-dev/` and rerun the role.

## Where to look when something fails

- `~/.local/share/omarchy-apple-dev/FINDINGS.md`: search it for the exact error text.
- `~/.local/share/omarchy-apple-dev/docs/OVER-TAILNET.md`: the cable-free route and its limits.
- `dotfiles` writes a log under `/var/lib/dotfiles/` or `/tmp/`.
