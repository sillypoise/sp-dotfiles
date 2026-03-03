#!/usr/bin/env zsh

SSH_AGENT_ENV_FILE="$HOME/.config/zsh/.ssh-agent.env"
SSH_GITHUB_KEY_FILE="$HOME/.ssh/gh_id_ed25519"

start_ssh_agent() {
  eval "$(ssh-agent -s)" >/dev/null
  {
    print -r -- "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
    print -r -- "export SSH_AGENT_PID=$SSH_AGENT_PID"
  } >|"$SSH_AGENT_ENV_FILE"
  chmod 600 "$SSH_AGENT_ENV_FILE"
}

load_cached_ssh_agent() {
  if [ -f "$SSH_AGENT_ENV_FILE" ]; then
    source "$SSH_AGENT_ENV_FILE" >/dev/null 2>&1 || true
  fi
}

ssh_agent_is_usable() {
  local ssh_add_rc

  if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "${SSH_AUTH_SOCK}" ]; then
    return 1
  fi

  ssh-add -l >/dev/null 2>&1
  ssh_add_rc=$?
  if [ "$ssh_add_rc" -eq 0 ] || [ "$ssh_add_rc" -eq 1 ]; then
    return 0
  fi

  return 1
}

ensure_ssh_github_key_loaded() {
  if [ ! -f "$SSH_GITHUB_KEY_FILE" ]; then
    return 0
  fi

  if ! ssh-add -l 2>/dev/null | command grep -q "$SSH_GITHUB_KEY_FILE"; then
    ssh-add "$SSH_GITHUB_KEY_FILE" >/dev/null || true
  fi
}

load_cached_ssh_agent
if ! ssh_agent_is_usable; then
  start_ssh_agent
fi
ensure_ssh_github_key_loaded
