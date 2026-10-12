"""Run the Swift role with real file/checksum tasks and simulated package/toolchain operations.

Cover repeat runs, pre-side-effect rejection, checksum failure, and failed init/install.
No system packages or real toolchains are installed by this suite.
"""

import hashlib
import os
import pathlib
import pwd
import shutil
import subprocess
import tarfile
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
FAKE_SWIFTLY = '''#!/usr/bin/python3
import os, pathlib, shutil, sys
home = pathlib.Path(os.environ["SWIFTLY_HOME_DIR"])
binary = pathlib.Path(os.environ["SWIFTLY_BIN_DIR"])
arguments = sys.argv[1:]
if arguments == ["--version"]:
    if os.environ.get("SWIFT_TEST_FAILURE") == "check": sys.exit(1)
    print("1.2.0")
elif arguments[0] == "init":
    if os.environ.get("SWIFT_TEST_FAILURE") == "init": sys.exit(1)
    binary.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(sys.argv[0], binary / "swiftly")
    (binary / "swiftly").chmod(0o755)
    (home / "env.sh").write_text('export PATH="' + str(binary) + ':$PATH"\\n')
elif arguments[0] == "install":
    if "--verify" not in arguments or "--use" in arguments: sys.exit(2)
    if os.environ.get("SWIFT_TEST_FAILURE") == "install": sys.exit(1)
    marker = home / "installed"
    print("already installed" if marker.exists() else "installed successfully!")
    marker.touch()
    for name in ("swift", "sourcekit-lsp"):
        target = binary / name
        target.write_text("#!/bin/sh\\necho 'Swift 6.4.0'\\n")
        target.chmod(0o755)
else:
    sys.exit(2)
'''


@unittest.skipUnless(shutil.which("ansible-playbook"), "Ansible is required")
class SwiftRoleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.home = self.root / "home"
        self.home.mkdir()
        installer = self.root / "swiftly"
        installer.write_text(FAKE_SWIFTLY)
        installer.chmod(0o755)
        self.archive = self.root / "installer.tar.gz"
        with tarfile.open(self.archive, "w:gz") as archive:
            archive.add(installer, arcname="swiftly")
        self.variables = yaml.safe_load((ROOT / "group_vars/all.yml").read_text())
        self.variables.update({
            "host_user_home": str(self.home),
            "host_user": pwd.getpwuid(os.getuid()).pw_name,
            "ansible_distribution": "Ubuntu",
            "ansible_distribution_version": "24.04",
            "ansible_architecture": "x86_64",
            "swiftly_archive_sha256": hashlib.sha256(self.archive.read_bytes()).hexdigest(),
        })
        self.tasks = yaml.safe_load((ROOT / "roles/swift/tasks/main.yml").read_text())
        ubuntu_tasks = yaml.safe_load((ROOT / "roles/swift/tasks/ubuntu.yml").read_text())
        ubuntu_tasks[0] = {
            "name": "Simulate apt", "ansible.builtin.debug": {"msg": "apt"}, "tags": ["swift"],
        }
        ubuntu_tasks[1]["become"] = False
        download = ubuntu_tasks[1]["block"][1]["ansible.builtin.get_url"]
        download["url"] = self.archive.as_uri()
        self.tasks[1].pop("ansible.builtin.import_tasks")
        self.tasks[1]["block"] = ubuntu_tasks

    def run_role(self, failure="", explicit=True):
        playbook = self.root / "play.yml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost", "gather_facts": False,
            "vars": self.variables, "tasks": self.tasks,
        }]))
        arguments = ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook)]
        if explicit:
            arguments.extend(["--tags", "swift"])
        result = subprocess.run(
            arguments,
            env=dict(os.environ, SWIFT_TEST_FAILURE=failure),
            capture_output=True, text=True, timeout=90,
        )
        return result.returncode, result.stdout + result.stderr

    def test_install_and_repeat(self):
        for repeat in (False, True):
            status, output = self.run_role()
            self.assertEqual(status, 0, output)
            if repeat:
                self.assertIn("changed=0", output)
            self.assertTrue((self.home / ".local/share/swiftly/installed").exists())
            for directory, extension in (("bash", "bash"), ("zsh", "zsh")):
                snippet = self.home / f".config/{directory}/zz-swift.{extension}"
                self.assertIn("env.sh", snippet.read_text())
                self.assertEqual(snippet.stat().st_uid, os.getuid())

    def test_reject_unsupported_or_invalid_inputs_before_side_effects(self):
        for name, value in (("ansible_distribution", "Archlinux"),
                            ("ansible_distribution_version", "22.04"),
                            ("ansible_architecture", "aarch64"),
                            ("swift_toolchain_version", "latest"),
                            ("swiftly_archive_sha256", "invalid")):
            with self.subTest(name=name):
                original = self.variables[name]
                self.variables[name] = value
                status, output = self.run_role()
                self.assertNotEqual(status, 0, output)
                self.assertNotIn("TASK [Simulate apt]", output)
                self.assertEqual(list(self.home.iterdir()), [])
                self.variables[name] = original

    def test_unsupported_default_run_skips_without_side_effects(self):
        self.variables["ansible_distribution"] = "Archlinux"
        status, output = self.run_role(explicit=False)
        self.assertEqual(status, 0, output)
        self.assertIn("Skipping Swift", output)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_checksum_mismatch_never_executes_installer(self):
        self.variables["swiftly_archive_sha256"] = "0" * 64
        status, output = self.run_role()
        self.assertNotEqual(status, 0, output)
        self.assertIn("checksum", output)
        self.assertFalse((self.home / ".local/share/swiftly").exists())

    def test_operating_failures_do_not_publish_shell_configuration(self):
        for failure in ("init", "install"):
            with self.subTest(failure=failure):
                status, output = self.run_role(failure)
                self.assertNotEqual(status, 0, output)
                self.assertFalse((self.home / ".local/share/swiftly/installed").exists())
                self.assertFalse((self.home / ".config").exists())
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        snippet = self.home / ".config/zsh/zz-swift.zsh"
        original = snippet.read_bytes()
        for failure in ("check", "install"):
            status, output = self.run_role(failure)
            self.assertNotEqual(status, 0, output)
            self.assertEqual(snippet.read_bytes(), original)
            self.assertTrue((self.home / ".local/share/swiftly/installed").exists())
