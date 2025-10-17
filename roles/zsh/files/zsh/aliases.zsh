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
