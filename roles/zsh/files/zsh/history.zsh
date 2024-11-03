HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST="${HISTSIZE}"

# Set history options for command management
setopt append_history          # Append history to the history file (do not overwrite)
setopt inc_append_history       # Immediately append commands as they are entered
setopt share_history            # Share history across all Zsh sessions
setopt extended_history         # Save timestamps and command durations
setopt hist_expire_dups_first   # Expire oldest duplicates first
setopt hist_ignore_all_dups     # Ignore all duplicates, keeping only the most recent entry
setopt hist_ignore_space        # Ignore commands prefixed with a space
setopt hist_reduce_blanks       # Remove extra blanks from commands

# Enable history search with up and down arrows
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n "$key[Up]"   ]] && bindkey -- "$key[Up]"   up-line-or-beginning-search
[[ -n "$key[Down]" ]] && bindkey -- "$key[Down]" down-line-or-beginning-search

