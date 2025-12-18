##### ZSH LINE EDITING / KEYMAPS #####

# We are using emacs-style line editing (default)
# bindkey -v   # ← keep commented unless you want vi-mode in the shell

# --- Prefix-aware history navigation ---
autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Ctrl-P / Ctrl-N
bindkey -M emacs '^P' up-line-or-beginning-search
bindkey -M emacs '^N' down-line-or-beginning-search
bindkey -M main  '^P' up-line-or-beginning-search
bindkey -M main  '^N' down-line-or-beginning-search

# Arrow keys (Up / Down)
bindkey -M emacs '^[[A' up-line-or-beginning-search
bindkey -M emacs '^[[B' down-line-or-beginning-search
bindkey -M main  '^[[A' up-line-or-beginning-search
bindkey -M main  '^[[B' down-line-or-beginning-search


# --- Incremental history search ---
bindkey -M emacs '^R' history-incremental-search-backward
bindkey -M main  '^R' history-incremental-search-backward


##### DIRECTORY NAVIGATION (ALT + ARROWS) #####

cdUndoKey() {
  popd > /dev/null
  zle reset-prompt
  echo
  ls
  echo
}

cdParentKey() {
  pushd .. > /dev/null
  zle reset-prompt
  echo
  ls
  echo
}

zle -N cdParentKey
zle -N cdUndoKey

# Alt + Up    → cd ..
# Alt + Left  → cd back
bindkey -M emacs '^[[1;3A' cdParentKey
bindkey -M emacs '^[[1;3D' cdUndoKey
bindkey -M main  '^[[1;3A' cdParentKey
bindkey -M main  '^[[1;3D' cdUndoKey


##### EDIT CURRENT COMMAND IN $EDITOR #####

autoload -Uz edit-command-line
zle -N edit-command-line

# Ctrl-X Ctrl-E → open current command line in $EDITOR
bindkey -M emacs '^X^E' edit-command-line
bindkey -M main  '^X^E' edit-command-line


##### OPTIONAL: VI-MODE COMPATIBILITY #####
# Safe to keep even if vi-mode is disabled

bindkey -M viins '^P' up-line-or-beginning-search
bindkey -M viins '^N' down-line-or-beginning-search
bindkey -M viins '^R' history-incremental-search-backward


