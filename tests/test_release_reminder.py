"""Run reminder branching in Ansible with mocked HTTP responses, not live upgrades.

Cover newer/equal/older releases, non-stable pins, missing Nix, check mode, and
invalid/unavailable metadata. Advisory failures must preserve a successful run.
"""

import pathlib
import subprocess
import tempfile
import unittest

import yaml


ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleaseReminderTests(unittest.TestCase):
    def run_case(self, *, payload=None, pin="nixos-25.11", nix_exists=True,
                 network_error=False, check_mode=False, reminder=False, warning=False):
        tasks = yaml.safe_load((ROOT / "roles/update/tasks/release-reminder.yml").read_text())
        fetch = tasks[0]["block"][0]
        fetch.pop("ansible.builtin.uri")
        fetch.pop("register")
        if network_error:
            fetch["ansible.builtin.fail"] = {"msg": "Simulated timeout or HTTP failure"}
        else:
            fetch["ansible.builtin.set_fact"] = {"update_nixos_releases": {"json": payload}}
        play = [{"hosts": "localhost", "gather_facts": False, "vars": {
            "update_nix_binary": {"stat": {"exists": nix_exists}},
            "nixpkgs_release": pin,
            "ansible_date_time": {"date": "2026-09-20"},
        }, "tasks": tasks}]

        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "play.yml"
            path.write_text(yaml.safe_dump(play))
            command = ["ansible-playbook", "--inventory", "localhost,", str(path)]
            if check_mode:
                command.append("--check")
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                    timeout=60, check=False)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertEqual("A newer stable Nixpkgs release is available:" in output, reminder, output)
        self.assertEqual("reminder check was unavailable" in output, warning, output)
        return output

    def test_release_comparison(self):
        payload = [{"cycle": "26.05", "releaseDate": "2026-05-30"}]
        self.run_case(payload=payload, reminder=True)
        self.run_case(payload=payload, pin="nixos-26.05")
        self.run_case(payload=payload, pin="nixos-26.11")

    def test_checks_skipped_when_not_applicable(self):
        for options in ({"pin": "nixos-unstable"}, {"nix_exists": False}, {"check_mode": True}):
            output = self.run_case(network_error=True, **options)
            self.assertNotIn("Simulated timeout", output)

    def test_unavailable_or_invalid_metadata_is_advisory(self):
        self.run_case(network_error=True, warning=True)
        for payload in (None, [], {}, "html", [None], [{}],
                        [{"cycle": "invalid", "releaseDate": "2026-05-30"}],
                        [{"cycle": "26.11", "releaseDate": "2026-11-30"}],
                        [{"cycle": "26.05", "releaseDate": "invalid"}]):
            with self.subTest(payload=payload):
                self.run_case(payload=payload, warning=True)

    def test_http_security_and_timeout(self):
        tasks = yaml.safe_load((ROOT / "roles/update/tasks/release-reminder.yml").read_text())
        fetch = tasks[0]["block"][0]
        options = fetch["ansible.builtin.uri"]
        self.assertFalse(fetch["become"])
        self.assertTrue(options["validate_certs"])
        self.assertFalse(options["use_netrc"])
        self.assertEqual(options["follow_redirects"], "none")
        self.assertEqual(options["timeout"], 10)


if __name__ == "__main__":
    unittest.main()
