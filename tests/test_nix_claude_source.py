"""Check source isolation and fail-closed behavior without fetching or installing packages."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest

from jinja2 import Template


ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("nix"), "Nix is required for configuration evaluation")
class ClaudeSourceTests(unittest.TestCase):
    def test_source_isolation_and_missing_package(self):
        # Stub package sets expose source selection, including the excluded missing-package state.
        template = (ROOT / "roles/nix/templates/flake.nix.j2").read_text()
        rendered = Template(template).render(
            nixpkgs_release="nixos-26.05",
            home_manager_release="release-26.05",
            nix_system="x86_64-linux",
            host_user="sillypoise",
        )

        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "flake.nix").write_text(rendered)
            (root / "stable.nix").write_text('{ ... }: { source = "stable"; }')
            unstable = root / "unstable.nix"
            unstable.write_text('{ ... }: { claude-code = "unstable-claude"; }')
            expression = f'''
              let
                flake = import {root}/flake.nix;
                output = flake.outputs {{
                  nixpkgs = {root}/stable.nix;
                  nixpkgs-unstable = {root}/unstable.nix;
                  home-manager.lib.homeManagerConfiguration = arguments: {{
                    stable = arguments.pkgs.source;
                    claude = arguments.extraSpecialArgs.claude_code;
                  }};
                }};
              in output.homeConfigurations.sillypoise
            '''
            command = [
                "nix", "--extra-experimental-features", "nix-command",
                "eval", "--impure", "--json", "--expr", expression,
            ]
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(),
                             '{"claude":"unstable-claude","stable":"stable"}')
            unstable.write_text('{ ... }: {}')
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("claude-code", result.stderr)

    def test_home_configuration_requires_selected_package(self):
        configuration = (ROOT / "roles/nix/files/sillypoise/home.nix").read_text()
        self.assertIn("claude_code, ...", configuration)
        self.assertEqual(configuration.count("      claude_code "), 1)
        self.assertNotIn('builtins.hasAttr "claude-code"', configuration)
