zja() {
  if ! command -v zellij >/dev/null 2>&1; then
    print "zja: zellij is not installed"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    print "zja: fzf is not installed"
    return 1
  fi

  local selected
  selected="$(zellij list-sessions --short 2>/dev/null | fzf --prompt='zellij attach> ' --height=40% --reverse)"

  if [[ -z "$selected" ]]; then
    return 0
  fi

  zellij attach "$selected"
}
