portkill() {
  local port="$1"
  local pid=""
  local proc_info=""
  local reply=""

  if [[ -z "$port" ]]; then
    print "usage: portkill <port>"
    return 1
  fi

  if [[ "$port" != <-> ]]; then
    print "portkill: port must be a number"
    return 1
  fi

  if (( port < 1 || port > 65535 )); then
    print "portkill: port must be between 1 and 65535"
    return 1
  fi

  if command -v lsof >/dev/null 2>&1; then
    pid="$(lsof -nP -iTCP:${port} -sTCP:LISTEN -t 2>/dev/null)"
    pid="${pid%%$'\n'*}"
  fi

  if [[ -z "$pid" ]] && command -v ss >/dev/null 2>&1; then
    local ss_line
    ss_line="$(ss -ltnp "( sport = :${port} )" 2>/dev/null | awk 'NR == 2 { print; exit }')"
    if [[ "$ss_line" == *"pid="* ]]; then
      pid="${ss_line##*pid=}"
      pid="${pid%%,*}"
    fi
  fi

  if [[ -z "$pid" ]]; then
    print "No listening process found on port ${port}."
    return 1
  fi

  if [[ "$pid" != <-> ]]; then
    print "portkill: failed to parse PID for port ${port}"
    return 1
  fi

  proc_info="$(ps -p "$pid" -o user=,pid=,ppid=,etime=,command= 2>/dev/null)"
  if [[ -z "$proc_info" ]]; then
    print "portkill: process ${pid} exited before lookup completed"
    return 1
  fi

  print "Port ${port} is used by:"
  print "${proc_info}"
  print ""
  read "reply?Kill PID ${pid}? [y/N]: "

  case "$reply" in
    y|Y|yes|YES)
      if kill "$pid" 2>/dev/null; then
        if kill -0 "$pid" 2>/dev/null; then
          print "Sent SIGTERM to PID ${pid}, but it is still running."
          print "You can inspect it in btop and kill manually if needed."
          return 1
        fi
        print "Killed PID ${pid} on port ${port}."
        return 0
      fi
      print "portkill: failed to kill PID ${pid} (permission denied or already exited)"
      return 1
      ;;
    *)
      print "Canceled."
      return 0
      ;;
  esac
}
