"""Exercise SSH host isolation and secret installation using a local fake op command."""

import os
import pathlib
import pwd
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ExeSSHTests(unittest.TestCase):
    def test_host_selection(self):
        for host in ("exe.dev", "vm.exe.xyz", "github.com", "unrelated.example"):
            result = subprocess.run(
                ["ssh", "-G", "-F", str(ROOT / "roles/ssh/files/config"), host],
                capture_output=True, text=True, timeout=10, check=True,
            )
            if host in ("exe.dev", "vm.exe.xyz"):
                self.assertIn("identityfile ~/.ssh/id_ed25519_exe\n", result.stdout)
                self.assertIn("identitiesonly yes\n", result.stdout)
                self.assertIn("forwardagent no\n", result.stdout)
                self.assertNotIn("gh_id_ed25519", result.stdout)
            else:
                self.assertNotIn("id_ed25519_exe", result.stdout)

    @unittest.skipUnless(shutil.which("ansible-playbook"), "Ansible is required")
    def test_install_skip_and_failures(self):
        # Real key validation; fake injection covers denied access and invalid secret content.
        with tempfile.TemporaryDirectory() as directory:
            home = pathlib.Path(directory)
            (home / ".ssh").mkdir(mode=0o700)
            subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "",
                            "-f", str(home / "source")], check=True, timeout=10)
            command = home / "op"
            command.write_text(
                "#!/usr/bin/python3\nimport os, pathlib, sys\n"
                "if os.environ['CASE'] == 'denied': sys.exit(1)\n"
                "target = pathlib.Path(sys.argv[sys.argv.index('--out-file') + 1])\n"
                "target.write_bytes(pathlib.Path(os.environ['SOURCE']).read_bytes() "
                "if os.environ['CASE'] == 'valid' else b'invalid')\n"
                "target.chmod(0o600)\n"
            )
            command.chmod(0o755)
            tasks = yaml.safe_load((ROOT / "roles/ssh/tasks/exe.yml").read_text())
            tasks[0]["block"][1]["ansible.builtin.copy"]["src"] = str(
                ROOT / "roles/ssh/files/id_ed25519_exe.tpl")
            play = [{"hosts": "localhost", "gather_facts": False, "vars": {
                "host_user_home": str(home), "host_user": pwd.getpwuid(os.getuid()).pw_name,
                "facts_op_installed": True}, "tasks": tasks}]
            playbook = home / "play.yml"
            playbook.write_text(yaml.safe_dump(play))
            target = home / ".ssh/id_ed25519_exe"
            for case in ("skip", "valid", "valid", "denied", "invalid"):
                environment = dict(os.environ, PATH=f"{home}:{os.environ['PATH']}",
                                   CASE=case, SOURCE=str(home / "source"),
                                   OP_SERVICE_ACCOUNT_TOKEN="" if case == "skip" else "fake")
                result = subprocess.run(
                    ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook)],
                    env=environment, capture_output=True, text=True, timeout=60,
                )
                self.assertEqual(result.returncode == 0, case in ("skip", "valid"),
                                 result.stdout + result.stderr)
                self.assertEqual(list((home / ".ssh").glob(".exe-key-*")), [])
                if case == "skip":
                    self.assertFalse(target.exists())
                else:
                    self.assertEqual(target.read_bytes(), (home / "source").read_bytes())
                    self.assertEqual(target.stat().st_mode & 0o777, 0o600)
