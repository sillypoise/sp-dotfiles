# Aliases
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias br="broot"
alias brt="broot --cmd :print_tree"
alias c='clear'
alias cp='cp -iv'
alias cat="bat"
alias chmod="chmod -c"
alias chown="chown -c"
alias find="fd"
alias grep="rg"
alias lg="lazygit"
alias ld="lazydocker"
alias ls="exa"
alias ll="exa -l"
alias oc="opencode -c"
alias oci="opencode-init-repo"
alias sed="sd"
alias extip='curl https://myip.wtf/text'
alias extipjson='curl https://myip.wtf/json'
alias mkdir='mkdir -pv'
alias mv='mv -iv'
alias ports='netstat -tulanp'
alias rm='rm -iv'
alias rmdir='rmdir -v'
alias sqsh="squoosh-cli"
alias pnpma="pnpm approve-builds"
# alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python -'
alias vim="nvim"
alias svim='sudo vim'
alias reload="source ~/.zshrc"
alias zj="zellij"
alias zjls="zellij list-sessions"
alias zshrc="nvim ~/.zshrc"
alias fjson="pbpaste | jq '.' | pbcopy"
alias watch='watch -d'
alias weather='curl wttr.in'
alias wget='wget -c'

# SSH
alias sshg='eval $(ssh-agent) && ssh-add ~/.ssh/gh_id_ed25519'
alias sshgv='eval $(ssh-agent) && ssh-add ~/.ssh/vanta_gh_id_ed25519'
alias ssha='eval $(ssh-agent) && ssh-add ~/.ssh/aws_id_ed25519'
alias sshsp='eval $(ssh-agent) && ssh-add ~/.ssh/sp_work_ed25519'

## Python aliases
alias py="python3"
alias pvenv='python3 -m venv venv && ln -s venv/bin/activate .activate.sh && echo "deactivate" > .deactivate.sh'

## SQLite
alias sqlite="sqlite3"
alias sqlu="sqlite-utils"

# git aliases
alias g="git"
alias gs="git status"
alias ga="git add"
alias gci="git commit"
alias gP="git push"
alias gf="git fetch"
alias gp="git pull"
alias gpr="git pull --rebase"
alias gco="git checkout"

# GH & Copilot CLI 
alias ghas="gh auth switch"

# Remote Development Servers
alias rds-sp="ssh sillypoise@sp-dev"

# Postgres helpers
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
  local target="${1:-dev}"
  local -a env_candidates

  case "$target" in
    dev|development)
      env_candidates=(.env.dev .env.development .env)
      ;;
    prod|production)
      env_candidates=(.env.prod .env.production .env)
      ;;
    stage|staging)
      env_candidates=(.env.stage .env.staging .env)
      ;;
    *)
      env_candidates=(".env.${target}" .env)
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
  PGPASSWORD="$pgpassword" psql "${psql_args[@]}"
}

alias dbd='dbconn dev'
alias dbp='dbconn prod'
alias dbs='dbconn staging'
