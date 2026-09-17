"""Exercise real Ansible branching with simulated I/O, never upgrading the test host.

Cover both distros, absent/incomplete Nix, missing lock, unsupported OS, and failures
at each mutation step. Assertions check that later effects never follow a failure.
Run with /usr/bin/python3 -m unittest discover -s tests -v.
"""

import pathlib
import subprocess
import tempfile
import unittest

import yaml


ROOT = pathlib.Path(__file__).resolve().parents[1]


def simulated_tasks(*, nix_exists, files_exist, executable, failure):
    tasks = yaml.safe_load((ROOT / "roles/update/tasks/main.yml").read_text())
    apply_tasks = yaml.safe_load((ROOT / "roles/nix/tasks/apply.yml").read_text())
    tasks.pop()  # Release lookup is exercised separately without network access.
    tasks[-1:] = [dict(apply_tasks[0], when=tasks[-1]["when"])]
    events = iter(["apt", "pacman", "lock", "apply"])
    for task in tasks:
        if "ansible.builtin.stat" in task:
            variable = task.pop("register")
            task.pop("ansible.builtin.stat")
            task.pop("loop", None)
            value = {"stat": {"exists": nix_exists, "executable": executable}}
            if variable == "update_home_manager_files":
                value = {"results": [{"stat": {"isreg": exists}} for exists in files_exist]}
            task["ansible.builtin.set_fact"] = {variable: value}
        for module in ("ansible.builtin.apt", "community.general.pacman", "ansible.builtin.shell"):
            if module not in task:
                continue
            task.pop(module)
            for key in ("args", "register", "changed_when", "become_user"):
                task.pop(key, None)
            event = next(events)
            replacement = "ansible.builtin.fail" if event == failure else "ansible.builtin.debug"
            task[replacement] = {"msg": "EVENT:" + event}
    return tasks


class UpdateRoleTests(unittest.TestCase):
    def run_case(self, *, distro="ubuntu", nix_exists=True, files_exist=(True, True),
                 executable=True, failure=None, expected=(), succeeds=True):
        tasks = simulated_tasks(nix_exists=nix_exists, files_exist=files_exist,
                                executable=executable, failure=failure)
        play = [{"hosts": "localhost", "gather_facts": False, "vars": {
            "facts_is_ubuntu": distro in ("ubuntu", "both"),
            "facts_is_arch": distro in ("arch", "both"),
        }, "tasks": tasks}]

        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "play.yml"
            path.write_text(yaml.safe_dump(play))
            result = subprocess.run(
                ["ansible-playbook", "--inventory", "localhost,",
                 "--connection", "local", str(path)],
                cwd=ROOT, capture_output=True, text=True, timeout=60, check=False,
            )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode == 0, succeeds, output)
        for event in ("apt", "pacman", "lock", "apply"):
            self.assertEqual("EVENT:" + event in output, event in expected, output)

    def test_platforms_and_absent_nix(self):
        for distro, package_event in (("ubuntu", "apt"), ("arch", "pacman")):
            with self.subTest(distro=distro):
                self.run_case(distro=distro, expected=(package_event, "lock", "apply"))
                self.run_case(distro=distro, nix_exists=False, expected=(package_event,))

    def test_preflight_rejections_have_no_effects(self):
        for distro in ("unsupported", "both"):
            self.run_case(distro=distro, succeeds=False)
        self.run_case(executable=False, succeeds=False)
        for files in ((False, True), (True, False), (False, False)):
            self.run_case(files_exist=files, succeeds=False)

    def test_failures_stop_later_effects(self):
        self.run_case(failure="apt", expected=("apt",), succeeds=False)
        self.run_case(distro="arch", failure="pacman", expected=("pacman",), succeeds=False)
        self.run_case(failure="lock", expected=("apt", "lock"), succeeds=False)
        self.run_case(failure="apply", expected=("apt", "lock", "apply"), succeeds=False)

    def test_opt_in_and_module_contracts(self):
        defaults = yaml.safe_load((ROOT / "group_vars/all.yml").read_text())
        self.assertNotIn("update", defaults["default_roles"])
        tasks = yaml.safe_load((ROOT / "roles/update/tasks/main.yml").read_text())
        for task in tasks:
            self.assertIn("update", task["tags"])
        apt = next(task["ansible.builtin.apt"] for task in tasks if "ansible.builtin.apt" in task)
        self.assertEqual(apt["upgrade"], "safe")
        self.assertTrue(apt["fail_on_autoremove"])
        self.assertFalse(apt["autoremove"])
        lock = next(task for task in tasks if "ansible.builtin.shell" in task)
        self.assertNotIn("creates", lock["args"])  # Missing and existing locks both update.
        self.assertEqual(lock["become_user"], "{{ host_user }}")
        self.assertIn("set -e", lock["ansible.builtin.shell"])
        self.assertEqual(tasks[-2]["ansible.builtin.import_role"]["tasks_from"], "apply")
        self.assertEqual(tasks[-1]["ansible.builtin.import_tasks"], "release-reminder.yml")


if __name__ == "__main__":
    unittest.main()
