_dbconn_read_env_var() {
  local key="$1"
  local env_file="$2"
  local value

  value="$(awk -v k="$key" '
    $0 ~ "^[[:space:]]*(export[[:space:]]+)?" k "[[:space:]]*=" {
      sub(/^[[:space:]]*(export[[:space:]]+)?/, "", $0)
      sub("^[[:space:]]*" k "[[:space:]]*=[[:space:]]*", "", $0)
      print $0
    }
  ' "$env_file" | tail -n 1)"

  value="${${value##[[:space:]]#}%%[[:space:]]#}"

  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi

  print -r -- "$value"
}

dbconn() {
  local echo_only=0
  local target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --echo|-e)
        echo_only=1
        ;;
      -h|--help)
        print "usage: dbconn [--echo] [env]"
        print "  env defaults to 'dev'"
        print "  examples: dbconn dev | dbconn prod | dbconn --echo staging"
        return 0
        ;;
      *)
        if [[ -n "$target" ]]; then
          print "dbconn: unexpected argument '$1'"
          return 1
        fi
        target="$1"
        ;;
    esac
    shift
  done

  target="${target:-dev}"
  local -a env_candidates

  case "$target" in
    dev|development)
      env_candidates=(.env.dev.local .env.development.local .env.local .env.dev .env.development .env)
      ;;
    prod|production)
      env_candidates=(.env.prod.local .env.production.local .env.prod .env.production .env)
      ;;
    stage|staging)
      env_candidates=(.env.stage.local .env.staging.local .env.stage .env.staging .env)
      ;;
    *)
      env_candidates=(".env.${target}.local" ".env.${target}" .env)
      ;;
  esac

  local env_file=""
  local candidate
  for candidate in "${env_candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      env_file="$candidate"
      break
    fi
  done

  if [[ -z "$env_file" ]]; then
    print "dbconn: no env file found (tried: ${env_candidates[*]})"
    return 1
  fi

  local database_url
  database_url="$(_dbconn_read_env_var "DATABASE_URL" "$env_file")"
  if [[ -n "$database_url" ]]; then
    print "dbconn: using ${env_file} -> DATABASE_URL"
    if [[ "$echo_only" -eq 1 ]]; then
      print "dbconn: dry-run, would run: psql <DATABASE_URL from ${env_file}>"
      return 0
    fi
    psql "$database_url"
    return
  fi

  local pghost pgport pguser pgpassword pgdatabase
  pghost="$(_dbconn_read_env_var "PGHOST" "$env_file")"
  pgport="$(_dbconn_read_env_var "PGPORT" "$env_file")"
  pguser="$(_dbconn_read_env_var "PGUSER" "$env_file")"
  pgpassword="$(_dbconn_read_env_var "PGPASSWORD" "$env_file")"
  pgdatabase="$(_dbconn_read_env_var "PGDATABASE" "$env_file")"

  if [[ -z "$pgdatabase" ]]; then
    print "dbconn: DATABASE_URL or PGDATABASE is required in ${env_file}"
    return 1
  fi

  local -a psql_args
  [[ -n "$pghost" ]] && psql_args+=("-h" "$pghost")
  [[ -n "$pgport" ]] && psql_args+=("-p" "$pgport")
  [[ -n "$pguser" ]] && psql_args+=("-U" "$pguser")
  psql_args+=("$pgdatabase")

  print "dbconn: using ${env_file} -> PG* variables"
  if [[ "$echo_only" -eq 1 ]]; then
    local shown_host="${pghost:-<default-host>}"
    local shown_port="${pgport:-<default-port>}"
    local shown_user="${pguser:-<default-user>}"
    print "dbconn: dry-run, would run: psql -h ${shown_host} -p ${shown_port} -U ${shown_user} ${pgdatabase}"
    return 0
  fi
  PGPASSWORD="$pgpassword" psql "${psql_args[@]}"
}

alias dbd='dbconn dev'
alias dbp='dbconn prod'
alias dbs='dbconn staging'
