"""Run the iOS role with real git/build/link tasks and simulated packages, sources, and installer.

Cover the pending-Xcode state, completion and repeat runs, pre-side-effect rejection, and a failing
installer. No system packages, real toolchains, or network sources are used by this suite.
"""

import os
import pathlib
import pwd
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
XTOOL_REVISION = "a" * 40
LIBRARIES = ("libplist", "libimobiledevice-glue", "libtatsu", "libimobiledevice")
FAKE_SWIFT = """#!/bin/sh
if [ "$1 $2" = "sdk list" ]; then
  if [ -d "$HOME/.swiftpm/swift-sdks/darwin.artifactbundle" ]; then echo darwin
  else echo "No Swift SDKs are currently installed."; fi
fi
"""
# Builds lib<name>.so.1 into the prefix; fails unless the libraries listed before it are installed.
FAKE_AUTOGEN = """#!/bin/sh
prefix=${1#--prefix=}
for dependency in %(dependencies)s; do
  pkg-config --exists "$dependency" || { echo "missing $dependency" >&2; exit 1; }
done
case "$LDFLAGS" in *"-rpath,$prefix/lib"*) ;; *) echo "missing rpath" >&2; exit 1 ;; esac
cat > Makefile <<MAKE
all:
\ttrue
install:
\tmkdir -p $prefix/lib/pkgconfig
\ttouch $prefix/lib/%(name)s.so.1.0.0
\tln -sfn %(name)s.so.1.0.0 $prefix/lib/%(name)s.so.1
\tprintf 'Name: %(name)s\\\\nDescription: fake\\\\nVersion: 1\\\\n' > $prefix/lib/pkgconfig/%(name)s.pc
MAKE
"""
# Mirrors the real installer's contract: tools first, then the SDK step that needs the Xcode archive.
FAKE_INSTALLER = """#!/usr/bin/env bash
set -euo pipefail
XTOOL_SHA=%(revision)s
[ "$*" = "--mode full" ] || exit 2
case "$(command -v swift)" in */toolchains/*/usr/bin/swift) ;; *) echo "proxy swift" >&2; exit 2 ;; esac
pkg-config --exists libimobiledevice || { echo "private prefix not visible" >&2; exit 2; }
echo run >> "$HOME/installer-runs"
[ "${IOS_TEST_FAILURE:-}" = install ] && exit 3
dest="$HOME/.local/lib/omarchy-apple-dev/xtool-$XTOOL_SHA"
[ -e "$dest/libimobiledevice.so.1" ] || { echo "libraries not linked next to xtool" >&2; exit 2; }
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\\necho tool\\n' > "$dest/xtool"
chmod 755 "$dest/xtool"
for tool in xtool rcodesign ipsw; do ln -sfn "$dest/xtool" "$HOME/.local/bin/$tool"; done
bundle="$HOME/.swiftpm/swift-sdks/darwin.artifactbundle"
if [ -d "$bundle" ]; then
  echo "Darwin SDK already registered; skipping install."
elif [ -n "${XCODE_XIP:-}" ] && [ -f "$XCODE_XIP" ]; then
  mkdir -p "$bundle"
else
  echo " One download left: the iOS SDK comes from Apple, inside Xcode.xip."
  exit 1
fi
"""


def git(directory, *arguments):
    environment = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
                       GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")
    return subprocess.run(["git", "-C", str(directory), *arguments], env=environment, check=True,
                          capture_output=True, text=True).stdout.strip()


@unittest.skipUnless(shutil.which("ansible-playbook") and shutil.which("make"), "Ansible and make are required")
class IosRoleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.home = self.root / "home"
        self.variables = yaml.safe_load((ROOT / "group_vars/all.yml").read_text())
        self.swift_bin = (self.home / ".local/share/swiftly/toolchains"
                          / self.variables["swift_toolchain_version"] / "usr/bin")
        self.swift_bin.mkdir(parents=True)
        (self.swift_bin / "swift").write_text(FAKE_SWIFT)
        (self.swift_bin / "swift").chmod(0o755)
        sources = []
        for index, name in enumerate(LIBRARIES):
            dependencies = " ".join(LIBRARIES[:index])
            ref = self.repository(name, "autogen.sh", FAKE_AUTOGEN % {"name": name, "dependencies": dependencies})
            sources.append({"name": name, "ref": ref})
        installer = self.repository("installer", "install-toolchain.sh", FAKE_INSTALLER % {"revision": XTOOL_REVISION})
        self.variables.update({
            "host_user_home": str(self.home),
            "host_user": pwd.getpwuid(os.getuid()).pw_name,
            "ansible_distribution": "Ubuntu",
            "ansible_distribution_version": "24.04",
            "ansible_architecture": "x86_64",
            "ios_toolchain_repo": str(self.root / "repositories/installer"),
            "ios_toolchain_ref": installer,
            "ios_imobiledevice_repo_base": str(self.root / "repositories"),
            "ios_imobiledevice_sources": sources,
            "ios_python": "/usr/bin/python3",
        })
        self.tasks = yaml.safe_load((ROOT / "roles/ios/tasks/main.yml").read_text())
        ubuntu_tasks = yaml.safe_load((ROOT / "roles/ios/tasks/ubuntu.yml").read_text())
        self.assertIn("ansible.builtin.apt", ubuntu_tasks[0])
        ubuntu_tasks[0] = {"name": "Simulate apt", "ansible.builtin.debug": {"msg": "apt"}, "tags": ["ios"]}
        ubuntu_tasks[1]["become"] = False
        block = ubuntu_tasks[1]["block"]
        package = next(index for index, task in enumerate(block) if "ansible.builtin.pip" in task)
        block[package] = {"name": "Simulate pip", "ansible.builtin.debug": {"msg": "pip"}, "tags": ["ios"]}
        install = next(task for task in self.tasks if "ansible.builtin.import_tasks" in task)
        install.pop("ansible.builtin.import_tasks")
        install["block"] = ubuntu_tasks

    def repository(self, name, script, content):
        directory = self.root / "repositories" / name
        directory.mkdir(parents=True)
        git(directory, "init", "-q")
        (directory / script).write_text(content)
        (directory / script).chmod(0o755)
        git(directory, "add", "-A")
        git(directory, "commit", "-q", "-m", "fake")
        return git(directory, "rev-parse", "HEAD")

    def run_role(self, failure=""):
        playbook = self.root / "play.yml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost", "gather_facts": False,
            "vars": self.variables, "tasks": self.tasks,
        }]))
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook), "--tags", "ios"],
            env=dict(os.environ, IOS_TEST_FAILURE=failure),
            capture_output=True, text=True, timeout=180,
        )
        return result.returncode, result.stdout + result.stderr

    def installer_runs(self):
        log = self.home / "installer-runs"
        return len(log.read_text().splitlines()) if log.exists() else 0

    def markers(self):
        state = self.home / ".local/state/ios-dev"
        return list(state.glob("installed-*")) if state.exists() else []

    def test_unxip_system_headers_are_installed_before_the_build(self):
        # Fake builds cannot detect absent host headers; check the real apt contract separately.
        tasks = yaml.safe_load((ROOT / "roles/ios/tasks/ubuntu.yml").read_text())
        packages = tasks[0]["ansible.builtin.apt"]
        self.assertIn("liblzma-dev", packages["name"])
        self.assertIn("zlib1g-dev", packages["name"])
        self.assertEqual(packages["state"], "present")
        self.assertTrue(tasks[0]["become"])
        self.assertIn("block", tasks[1])

    def test_pending_then_complete_then_repeat(self):
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertIn("iOS SDK pending", output)
        self.assertEqual(self.markers(), [])
        xtool_directory = self.home / ".local/lib/omarchy-apple-dev" / f"xtool-{XTOOL_REVISION}"
        for name in LIBRARIES:
            link = xtool_directory / f"{name}.so.1"
            self.assertTrue(link.is_symlink() and link.exists(), link)
            self.assertIn("/.local/lib/ios-dev/imobiledevice-", os.readlink(link))
        # The pending state keeps asking the installer until the archive arrives.
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertEqual(self.installer_runs(), 2)
        archive = pathlib.Path(self.variables["ios_xcode_xip"].replace("{{ host_user_home }}", str(self.home)))
        archive.parent.mkdir(parents=True)
        archive.write_bytes(b"xip")
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertNotIn("iOS SDK pending", output)
        self.assertEqual(len(self.markers()), 1)
        self.assertEqual(self.installer_runs(), 3)
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertIn("changed=0", output)
        self.assertEqual(self.installer_runs(), 3)

    def test_reject_unsupported_or_invalid_inputs_before_side_effects(self):
        before = sorted(str(path) for path in self.home.rglob("*"))
        for name, value in (("ansible_distribution", "Archlinux"),
                            ("ansible_distribution_version", "22.04"),
                            ("ansible_architecture", "aarch64"),
                            ("ios_toolchain_ref", "main"),
                            ("ios_imobiledevice_sources", [{"name": "libplist", "ref": "master"}]),
                            ("ios_pymobiledevice3_version", "latest"),
                            ("ios_python", "/nonexistent/python3.13"),
                            ("swift_toolchain_version", "9.9.9")):
            with self.subTest(name=name):
                original = self.variables[name]
                self.variables[name] = value
                status, output = self.run_role()
                self.assertNotEqual(status, 0, output)
                self.assertNotIn("TASK [Simulate apt]", output)
                self.assertEqual(sorted(str(path) for path in self.home.rglob("*")), before)
                self.variables[name] = original

    def test_virtualenv_without_tunnel_support_is_replaced(self):
        virtualenv = self.home / "pymobile3-venv"
        (virtualenv / "bin").mkdir(parents=True)
        (virtualenv / "bin/python").write_text("#!/bin/sh\nexit 3\n")
        (virtualenv / "bin/python").chmod(0o755)
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        # Pip is simulated here, so a removed virtualenv stays absent.
        self.assertFalse(virtualenv.exists())
        (virtualenv / "bin").mkdir(parents=True)
        (virtualenv / "bin/python").write_text("#!/bin/sh\nexit 0\n")
        (virtualenv / "bin/python").chmod(0o755)
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertTrue((virtualenv / "bin/python").exists())

    def test_installer_failure_fails_the_role_without_a_marker(self):
        status, output = self.run_role("install")
        self.assertNotEqual(status, 0, output)
        self.assertEqual(self.installer_runs(), 1)
        self.assertEqual(self.markers(), [])
        self.assertFalse((self.home / ".local/bin/xtool").exists())
