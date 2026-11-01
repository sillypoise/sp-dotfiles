"""Run the Rex role with real file/checksum tasks and simulated apt, loginctl, and systemd.

Cover install and repeat runs, the restart policy for a running server, pre-side-effect
rejection, a changed signing key, and a Perl rex winning apt. Nothing outside a temporary
directory is written, and the real rex.service is never touched.
"""

import hashlib
import os
import pathlib
import pwd
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
# Logs each call and keeps service state in a file, so tests can assert what ran.
FAKE_TOOL = '''#!/usr/bin/python3
import os, pathlib, sys
state = pathlib.Path(os.environ["REX_TEST_STATE"])
name = pathlib.Path(sys.argv[0]).name
with open(state / "calls", "a") as calls:
    calls.write(" ".join([name] + sys.argv[1:]) + "\\n")
active = state / ("active-" + sys.argv[-1])
if name == "rex":
    if sys.argv[1:] == ["server", "--help"] and os.environ.get("REX_TEST_FAILURE") == "perl":
        sys.exit(1)
    print("tailscale: running")
elif name == "loginctl":
    (state / "linger").touch()
elif name == "systemctl":
    if "is-active" in sys.argv:
        print("active" if active.exists() else "inactive")
        sys.exit(0 if active.exists() else 3)
    if "start" in sys.argv or "restart" in sys.argv:
        active.touch()
'''
SYSTEMD = "ansible.builtin.systemd_service"


@unittest.skipUnless(shutil.which("ansible-playbook"), "Ansible is required")
class RexRoleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("rex", "loginctl", "systemctl"):
            tool = self.bin / name
            tool.write_text(FAKE_TOOL)
            tool.chmod(0o755)
        self.key = self.root / "key.gpg"
        self.key.write_bytes(b"fake key")
        # Present on every Ubuntu install.
        for directory in ("preferences.d", "sources.list.d"):
            (self.root / "etc/apt" / directory).mkdir(parents=True)
        self.variables = yaml.safe_load((ROOT / "group_vars/all.yml").read_text())
        self.variables.update({
            "host_user_home": str(self.home),
            "host_user": pwd.getpwuid(os.getuid()).pw_name,
            "ansible_distribution": "Ubuntu",
            "ansible_architecture": "x86_64",
            "rex_keyring_sha256": hashlib.sha256(self.key.read_bytes()).hexdigest(),
        })
        self.tasks = yaml.safe_load((ROOT / "roles/rex/tasks/main.yml").read_text())
        ubuntu_tasks = yaml.safe_load((ROOT / "roles/rex/tasks/ubuntu.yml").read_text())
        self.tasks[1].pop("ansible.builtin.import_tasks")
        self.tasks[1]["block"] = [self.simulate(task) for task in ubuntu_tasks]

    def simulate(self, task):
        task.pop("become", None)
        task.pop("become_user", None)
        if "block" in task:
            task["block"] = [self.simulate(child) for child in task["block"]]
            return task
        etc = str(self.root / "etc")
        for module in ("ansible.builtin.file", "ansible.builtin.get_url", "ansible.builtin.copy"):
            arguments = task.get(module)
            if arguments:
                for key in ("path", "dest"):
                    if key in arguments:
                        arguments[key] = arguments[key].replace("/etc", etc)
                arguments.pop("owner", None)
                arguments.pop("group", None)
        if "ansible.builtin.get_url" in task:
            task["ansible.builtin.get_url"]["url"] = self.key.as_uri()
        if "ansible.builtin.template" in task:
            task["ansible.builtin.template"]["src"] = str(ROOT / "roles/rex/templates/rex.service.j2")
        if "ansible.builtin.apt" in task:
            task.pop("ansible.builtin.apt")
            task["ansible.builtin.debug"] = {"msg": "simulated apt"}
        command = task.get("ansible.builtin.command")
        if command:
            command["argv"][0] = str(self.bin / pathlib.Path(command["argv"][0]).name)
            if "creates" in command:
                command["creates"] = str(self.state / "linger")
        if SYSTEMD in task:
            arguments = task.pop(SYSTEMD)
            action = {"started": "start", "restarted": "restart"}[arguments["state"]]
            argv = [str(self.bin / "systemctl")]
            if arguments.get("scope") == "user":
                argv.append("--user")
            task["ansible.builtin.command"] = {"argv": argv + [action, arguments["name"]]}
        return task

    def run_role(self, failure="", explicit=True, **overrides):
        variables = dict(self.variables, **overrides)
        playbook = self.root / "play.yml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost", "gather_facts": False,
            "vars": variables, "tasks": self.tasks,
        }]))
        arguments = ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook)]
        if explicit:
            arguments.extend(["--tags", "rex"])
        result = subprocess.run(
            arguments,
            env=dict(os.environ, REX_TEST_STATE=str(self.state), REX_TEST_FAILURE=failure,
                     PATH=f"{self.bin}:{os.environ['PATH']}"),
            capture_output=True, text=True, timeout=120,
        )
        return result.returncode, result.stdout + result.stderr

    def calls(self):
        path = self.state / "calls"
        return path.read_text().splitlines() if path.exists() else []

    @property
    def unit(self):
        return self.home / ".config/systemd/user/rex.service"

    def test_install_and_repeat(self):
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertIn("--tailscale-hostname sp-dev-rex ", self.unit.read_text())
        self.assertIn("unix://%t/rex/server.sock", self.unit.read_text())
        self.assertEqual(self.unit.stat().st_mode & 0o777, 0o644)
        sources = (self.root / "etc/apt/sources.list.d/rex.sources").read_text()
        self.assertIn("Suites: snapshot\n", sources)
        self.assertIn("Architectures: amd64\n", sources)
        self.assertIn("Pin-Priority: 1001", (self.root / "etc/apt/preferences.d/rex").read_text())
        self.assertIn("systemctl --user start rex.service", self.calls())
        self.assertIn("loginctl enable-linger", "\n".join(self.calls()))
        self.assertNotIn("was not restarted", output)

        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertEqual(1, "\n".join(self.calls()).count("loginctl enable-linger"))
        self.assertNotIn("restart rex.service", "\n".join(self.calls()))

    def test_changed_unit_on_running_server_waits_for_manual_restart(self):
        self.unit.parent.mkdir(parents=True)
        self.unit.write_text("[Service]\nExecStart=/usr/bin/rex server run --tailscale-hostname old\n")
        (self.state / "active-rex.service").touch()
        status, output = self.run_role()
        self.assertEqual(status, 0, output)
        self.assertIn("sp-dev-rex", self.unit.read_text())
        self.assertIn("was not restarted", output)
        self.assertNotIn("restart rex.service", "\n".join(self.calls()))

    def test_changed_unit_restarts_when_allowed(self):
        self.unit.parent.mkdir(parents=True)
        self.unit.write_text("[Service]\n")
        (self.state / "active-rex.service").touch()
        status, output = self.run_role(rex_restart_on_change=True)
        self.assertEqual(status, 0, output)
        self.assertIn("systemctl --user restart rex.service", self.calls())
        self.assertNotIn("was not restarted", output)

    def test_reject_unsupported_or_invalid_inputs_before_side_effects(self):
        for name, value in (("ansible_distribution", "Archlinux"),
                            ("ansible_architecture", "riscv64"),
                            ("rex_channel", "nightly"),
                            ("rex_keyring_sha256", "invalid"),
                            ("rex_tailscale_hostname", "Bad Name")):
            with self.subTest(name=name):
                status, output = self.run_role(**{name: value})
                self.assertNotEqual(status, 0, output)
                self.assertFalse((self.root / "etc/apt/keyrings").exists())
                self.assertEqual(self.calls(), [])

    def test_unsupported_default_run_skips_without_side_effects(self):
        status, output = self.run_role(explicit=False, ansible_distribution="Archlinux")
        self.assertEqual(status, 0, output)
        self.assertIn("Skipping Rex", output)
        self.assertFalse((self.root / "etc/apt/keyrings").exists())
        self.assertEqual(self.calls(), [])

    def test_changed_signing_key_fails_before_install(self):
        status, output = self.run_role(rex_keyring_sha256="0" * 64)
        self.assertNotEqual(status, 0, output)
        self.assertIn("checksum", output)
        self.assertFalse((self.root / "etc/apt/keyrings/rex-archive-keyring.gpg").exists())
        self.assertFalse((self.root / "etc/apt/sources.list.d/rex.sources").exists())
        self.assertFalse(self.unit.exists())

    def test_perl_rex_fails_before_service_setup(self):
        status, output = self.run_role(failure="perl")
        self.assertNotEqual(status, 0, output)
        self.assertFalse(self.unit.exists())
        self.assertNotIn("loginctl", "\n".join(self.calls()))


if __name__ == "__main__":
    unittest.main()
