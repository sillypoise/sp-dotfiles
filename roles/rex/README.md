# rex

Runs a personal [Rex](https://www.superlogical.com/rex/docs/linux/server-modes) server as the
host user, reachable over its own embedded Tailscale node ("Built-in Tailscale" in the
[remote access docs](https://www.superlogical.com/rex/docs/linux/remote-access)).

## Contract

- Ubuntu on x86_64 or aarch64 only. Unsupported default runs skip; `dotfiles -t rex` fails first.
- Installs `rex` from `pkgs.superlogical.com` on `rex_channel`, like the upstream `install.sh`:
  checksum-pinned keyring, deb822 source, and an apt pin of 1001 so Ubuntu's unrelated Perl
  `rex` never wins. The role fails if `/usr/bin/rex` is not the Rex server.
- Writes `~/.config/systemd/user/rex.service`, enables it, and enables linger so it starts at boot.
  The server listens on `$XDG_RUNTIME_DIR/rex/server.sock`, so plain `rex` commands use it.
- The tailnet device is `rex_tailscale_hostname` (default `<system_hostname>-rex`, `sp-dev-rex`).
  Only the device owner can connect (no `--tailscale-allow-tailnet-members`).
- The packaged system units (`rex.service`, `rex-login-server.service`) stay disabled.
- The system `tailscaled` is not involved; the tailscale role needs no changes. The tailnet
  needs MagicDNS and HTTPS certificates turned on.

## Restarts

Restarting the server ends every program running in its sessions. When the unit changes while
the server runs, the role reports it and leaves the server alone unless
`rex_restart_on_change: true`. Apply it later with `systemctl --user restart rex.service`.

## New machine

The first start has no Tailscale login. The role prints `rex server status`, which shows a
sign-in link; open it once. The login is kept in `~/.local/state/rex/tsnet`, which the role never
touches. Then add `https://<rex_tailscale_hostname>.<tailnet>.ts.net` in the Rex client.

## Updating

Rex updates arrive with normal apt upgrades (`dotfiles -t update`). Apt does not restart the
user service, so a new version takes effect on the next restart. If the repository signing
key changes, the role fails on the checksum; verify the new key and update `rex_keyring_sha256`.

## Tests

`/usr/bin/python3 -m unittest discover -s tests -p test_rex_role.py -v` runs the role with fake
apt, loginctl, systemctl, and rex, inside a temporary directory.
