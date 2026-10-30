# Source the first readable file from the arguments; skip silently when none exists.
source_first() {
  local f
  for f in "$@"; do [ -r "$f" ] && { source "$f"; return; }; done
}

BREW="${HOMEBREW_PREFIX:-/opt/homebrew}"

# History
## A large shared history feeds autosuggestions and keeps tmux panes in sync.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# Completion
## Tab and Shift-Tab cycle with the current pick highlighted; Enter runs the command at once.
[ -d "$BREW/share/zsh/site-functions" ] && fpath=("$BREW/share/zsh/site-functions" $fpath)
zmodload zsh/complist
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive matching
zstyle ':completion:*' menu select                   # highlight the current candidate
bindkey '^[[Z' reverse-menu-complete                 # Shift-Tab outside the menu
bindkey -M menuselect '^[[Z' reverse-menu-complete   # Shift-Tab inside the menu
bindkey -M menuselect '^M' .accept-line              # Enter accepts and runs in one press

# Autosuggestions
## Fish-like history autosuggestions (grey ghost text, accept with Right Arrow)
source_first \
  "$BREW/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Starship
command -v starship >/dev/null && eval "$(starship init zsh)"

# Machine-local settings and secrets, kept out of the repo.
[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# Syntax highlighting
## Colours commands as you type; it must load last so it wraps every other widget.
source_first \
  "$BREW/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

unset BREW
unfunction source_first
