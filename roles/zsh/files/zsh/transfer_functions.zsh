#!/usr/bin/env zsh

: "${RDS_PEER:=}"
: "${RDS_EXPECT_HOST:=sp-dev}"
TRANSFER_ENV_FILE="$HOME/.config/zsh/transfer.env.zsh"

_transfer_load_saved_peer() {
  if [ -f "$TRANSFER_ENV_FILE" ]; then
    source "$TRANSFER_ENV_FILE" >/dev/null 2>&1 || true
  fi
}

_transfer_usage() {
  print "Usage: rput <local_src> [remote_dest]"
  print "       rget <remote_src> [local_dest]"
  print "       rputn <local_src> [remote_dest]  (dry-run)"
  print "       rgetn <remote_src> [local_dest]  (dry-run)"
  print "       rpeer [user@host]"
  print "       rpeer --clear"
  print ""
  print "Examples:"
  print "  rpeer sillypoise@my-mac"
  print "  rput ./build/ ~/Downloads/build/"
  print "  rget ~/Downloads/file ./"
}

_transfer_require_tools() {
  if ! command -v rsync >/dev/null 2>&1; then
    print "transfer: rsync is not installed"
    return 1
  fi

  if ! command -v ssh >/dev/null 2>&1; then
    print "transfer: ssh is not installed"
    return 1
  fi
}

_transfer_require_linux_host() {
  local short_host

  if [[ "${OSTYPE:-}" != linux* ]]; then
    print "transfer: this helper is intended for the Linux server only"
    print "  hint: run transfers from sp-dev or use native scp/rsync on this host"
    return 1
  fi

  if [[ -z "${RDS_EXPECT_HOST:-}" ]]; then
    return 0
  fi

  short_host="$(hostname -s 2>/dev/null || true)"
  if [[ -n "$short_host" && "$short_host" != "$RDS_EXPECT_HOST" ]]; then
    print "transfer: expected host '$RDS_EXPECT_HOST' but running on '$short_host'"
    print "  hint: set RDS_EXPECT_HOST='' to disable host pinning"
    return 1
  fi
}

_transfer_peer_host() {
  local peer="$1"
  print "${peer#*@}"
}

_transfer_peer_is_local() {
  local peer_host="$1"
  local short_host fqdn_host

  short_host="$(hostname -s 2>/dev/null || true)"
  fqdn_host="$(hostname -f 2>/dev/null || true)"

  case "$peer_host" in
    localhost|127.0.0.1|127.0.1.1)
      return 0
      ;;
  esac

  if [[ -n "$short_host" && "$peer_host" == "$short_host" ]]; then
    return 0
  fi

  if [[ -n "$fqdn_host" && "$peer_host" == "$fqdn_host" ]]; then
    return 0
  fi

  return 1
}

_transfer_connection_hint() {
  local peer="$1"

  print "transfer: unable to connect to $peer with SSH keys."
  print "  hint: verify with: ssh $peer"
  print "  hint: choose another endpoint with: rpeer user@host"
}

_transfer_run() {
  local mode="$1"
  local dry_run="$2"
  local src="${3:-}"
  local dst="${4:-}"
  local peer_host=""
  local rc
  local -a args

  if [[ -z "$src" ]]; then
    _transfer_usage
    return 1
  fi

  if [[ -z "$RDS_PEER" ]]; then
    print "transfer: RDS_PEER is empty"
    print "  hint: set peer first, example: rpeer sillypoise@my-mac"
    return 1
  fi

  _transfer_require_linux_host || return 1

  peer_host="$(_transfer_peer_host "$RDS_PEER")"
  if _transfer_peer_is_local "$peer_host"; then
    print "transfer: RDS_PEER ($RDS_PEER) points to this host."
    print "  hint: use local cp/mv or set peer first: rpeer user@other-host"
    return 1
  fi

  _transfer_require_tools || return 1

  args=(-a --human-readable --progress --partial)
  if [[ "$dry_run" == "1" ]]; then
    args+=(--dry-run --itemize-changes)
  fi

  if [[ "$mode" == "put" ]]; then
    if [[ -z "$dst" ]]; then
      dst="~"
    fi
    rsync "${args[@]}" -- "$src" "${RDS_PEER}:${dst}"
    rc=$?
    if [[ "$rc" -eq 255 ]]; then
      _transfer_connection_hint "$RDS_PEER"
    fi
    return "$rc"
  fi

  if [[ "$mode" == "get" ]]; then
    if [[ -z "$dst" ]]; then
      dst="."
    fi
    rsync "${args[@]}" -- "${RDS_PEER}:${src}" "$dst"
    rc=$?
    if [[ "$rc" -eq 255 ]]; then
      _transfer_connection_hint "$RDS_PEER"
    fi
    return "$rc"
  fi

  print "transfer: unknown mode '$mode'"
  return 1
}

rput() {
  _transfer_run put 0 "$@"
}

rget() {
  _transfer_run get 0 "$@"
}

rputn() {
  _transfer_run put 1 "$@"
}

rgetn() {
  _transfer_run get 1 "$@"
}

rpeer() {
  if [[ "$#" -eq 0 ]]; then
    print "$RDS_PEER"
    return 0
  fi

  if [[ "$1" == "--clear" ]]; then
    unset RDS_PEER
    command rm -f "$TRANSFER_ENV_FILE"
    print "RDS_PEER cleared"
    return 0
  fi

  if [[ "$1" == *[[:space:]]* ]]; then
    print "transfer: peer must not contain spaces"
    return 1
  fi

  if [[ ! "$1" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+$ ]]; then
    print "transfer: expected format user@host"
    return 1
  fi

  export RDS_PEER="$1"
  {
    print -r -- "export RDS_PEER=$RDS_PEER"
  } >|"$TRANSFER_ENV_FILE"
  chmod 600 "$TRANSFER_ENV_FILE"
  print "RDS_PEER=$RDS_PEER"
}

_transfer_load_saved_peer
