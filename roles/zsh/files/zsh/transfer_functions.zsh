#!/usr/bin/env zsh

: "${RDS_PEER:=sillypoise@sp-dev}"

_transfer_usage() {
  print "Usage: rput <local_src> [remote_dest]"
  print "       rget <remote_src> [local_dest]"
  print "       rputn <local_src> [remote_dest]  (dry-run)"
  print "       rgetn <remote_src> [local_dest]  (dry-run)"
  print "       rpeer [user@host]"
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

_transfer_run() {
  local mode="$1"
  local dry_run="$2"
  local src="${3:-}"
  local dst="${4:-}"
  local -a args

  if [[ -z "$src" ]]; then
    _transfer_usage
    return 1
  fi

  if [[ -z "$RDS_PEER" ]]; then
    print "transfer: RDS_PEER is empty"
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
    return $?
  fi

  if [[ "$mode" == "get" ]]; then
    if [[ -z "$dst" ]]; then
      dst="."
    fi
    rsync "${args[@]}" -- "${RDS_PEER}:${src}" "$dst"
    return $?
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

  export RDS_PEER="$1"
  print "RDS_PEER=$RDS_PEER"
}
