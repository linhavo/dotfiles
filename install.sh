#!/usr/bin/env bash
#
# Install these dotfiles into the current environment:
#   claude/* -> ~/.claude/*
#   config/* -> ~/.config/*
#   home/*   -> ~/*
#   profiles/<name>/ -> ~/.config/dotfiles/profile  (git and zsh load it on top of the base)
#
# Two modes:
#   symlink (default)  links back to this repo — edits show up in git right away.
#                      Requires the repo to stay where it is.
#   copy (--copy)      copies files in. Use for devcontainers, cloud sessions and
#                      anywhere the repo is transient or gets rebuilt.
#
# Usage:
#   ./install.sh                  # symlink, backing up what is in the way
#   ./install.sh --copy           # copy instead of linking
#   ./install.sh --dry-run        # show what would happen, change nothing
#   ./install.sh --force          # replace conflicting paths without backing up
#   ./install.sh --profile work   # pick a profile; later runs reuse it
#
# Profile: --profile, then the saved choice, then "container" inside a container.
#
# Env:
#   CLAUDE_CONFIG_DIR   target for claude/ (default: ~/.claude)
#   XDG_CONFIG_HOME     target for config/ (default: ~/.config)
#   DOTFILES_MODE       copy|symlink — same as --copy / default
#   DOTFILES_PROFILE    same as --profile
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
XDG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CLAUDE_HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STATE_DIR="$XDG_HOME/dotfiles"

MODE="${DOTFILES_MODE:-symlink}"
PROFILE="${DOTFILES_PROFILE:-}"
DRY_RUN=0
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --copy|-c)    MODE=copy ;;
    --symlink|-s) MODE=symlink ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --force|-f)   FORCE=1 ;;
    --profile|-p) [ "$#" -ge 2 ] || { echo "--profile needs a name" >&2; exit 2; }
                  PROFILE="$2"; shift ;;
    --profile=*)  PROFILE="${1#*=}" ;;
    --help|-h)    sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

case "$MODE" in
  copy|symlink) ;;
  *) echo "invalid mode: $MODE (expected copy or symlink)" >&2; exit 2 ;;
esac

in_container() {
  [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${REMOTE_CONTAINERS:-}" ] \
    || [ -n "${CODESPACES:-}" ] || [ -n "${DEVPOD:-}" ]
}

if [ -z "$PROFILE" ] && [ -r "$STATE_DIR/profile-name" ]; then PROFILE="$(cat "$STATE_DIR/profile-name")"; fi
if [ -z "$PROFILE" ] && in_container; then PROFILE=container; fi
if [ -n "$PROFILE" ] && [ ! -d "$DOTFILES_DIR/profiles/$PROFILE" ]; then
  echo "unknown profile: $PROFILE (expected one of: $(ls "$DOTFILES_DIR/profiles" | tr '\n' ' '))" >&2
  exit 2
fi

log() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then log "  would run: $*"; else "$@"; fi; }

# Move whatever currently sits at $1 out of the way (or delete it with --force).
clear_dest() {
  local dest="$1"
  [ -e "$dest" ] || [ -L "$dest" ] || return 0

  if [ "$FORCE" -eq 1 ]; then
    log "replace   $dest"
    run rm -rf "$dest"
  else
    # Mirror the full path so same-named files from different targets don't collide.
    local backup="$BACKUP_DIR$dest"
    log "backup    $dest -> $backup"
    run mkdir -p "$(dirname "$backup")"
    run mv "$dest" "$backup"
  fi
}

install_symlink() {
  local src="$1" dest="$2" child

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "ok        $dest (already linked)"
    return
  fi

  # A real directory already at the target keeps entries this repo does not
  # carry (e.g. ~/.claude/skills/synced), so link its children one level down
  # instead of replacing the directory itself.
  if [ -d "$src" ] && [ -d "$dest" ] && [ ! -L "$dest" ]; then
    shopt -s nullglob dotglob
    for child in "$src"/*; do
      case "$(basename "$child")" in
        .gitkeep|.DS_Store) continue ;;
      esac
      install_symlink "$child" "$dest/$(basename "$child")"
    done
    shopt -u nullglob dotglob
    return
  fi

  clear_dest "$dest"
  log "link      $dest"
  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
}

install_copy() {
  local src="$1" dest="$2"

  # A stale symlink from a previous symlink-mode install must go, otherwise the
  # copy would write straight through it into the repo.
  [ -L "$dest" ] && clear_dest "$dest"

  if [ -d "$src" ]; then
    # Merge into the target dir rather than clobbering it, so an existing
    # ~/.claude/skills keeps entries this repo does not carry.
    log "copy      $src/ -> $dest/"
    run mkdir -p "$dest"
    if [ "$DRY_RUN" -eq 0 ]; then
      # trailing /. copies contents, including dotfiles
      cp -R "$src/." "$dest/"
      rm -f "$dest/.gitkeep"
    fi
  else
    if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
      clear_dest "$dest"
    fi
    log "copy      $src -> $dest"
    run cp "$src" "$dest"
  fi
}

log "dotfiles: $DOTFILES_DIR"
log "target:   $CLAUDE_HOME, $XDG_HOME, $HOME"
log "mode:     $MODE"
log "profile:  ${PROFILE:-none}"
[ "$DRY_RUN" -eq 1 ] && log "(dry run — nothing will be changed)"
log ""

# Install every top-level entry of repo dir $1 into target dir $2.
install_tree() {
  local src_root="$1" dest_root="$2" entry name
  [ -d "$src_root" ] || return 0
  run mkdir -p "$dest_root"

  shopt -s nullglob dotglob
  for entry in "$src_root"/*; do
    name="$(basename "$entry")"
    case "$name" in
      .gitkeep|.DS_Store) continue ;;
    esac
    if [ "$MODE" = copy ]; then
      install_copy "$entry" "$dest_root/$name"
    else
      install_symlink "$entry" "$dest_root/$name"
    fi
  done
  shopt -u nullglob dotglob
}

install_tree "$DOTFILES_DIR/claude" "$CLAUDE_HOME"
install_tree "$DOTFILES_DIR/config" "$XDG_HOME"
install_tree "$DOTFILES_DIR/home" "$HOME"

# Install the chosen profile and save its name so later runs reuse it.
install_profile() {
  if [ -z "$PROFILE" ]; then
    log "skip      profile (none chosen; pass --profile <name>)"
    return
  fi
  run mkdir -p "$STATE_DIR"
  # A link to another profile only points into this repo, so replace it without a backup.
  local dest="$STATE_DIR/profile" src="$DOTFILES_DIR/profiles/$PROFILE"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" != "$src" ]; then run rm "$dest"; fi
  if [ "$MODE" = copy ]; then
    install_copy "$src" "$dest"
  else
    install_symlink "$src" "$dest"
  fi
  if [ "$(cat "$STATE_DIR/profile-name" 2>/dev/null)" != "$PROFILE" ]; then
    log "save      $STATE_DIR/profile-name = $PROFILE"
    [ "$DRY_RUN" -eq 1 ] || printf '%s\n' "$PROFILE" > "$STATE_DIR/profile-name"
  fi
}

install_profile

log ""
log "done."
