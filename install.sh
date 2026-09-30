#!/usr/bin/env bash
#
# Install these dotfiles into the current environment:
#   claude/* -> ~/.claude/*
#   config/* -> ~/.config/*
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
#
# Env:
#   CLAUDE_CONFIG_DIR   target for claude/ (default: ~/.claude)
#   XDG_CONFIG_HOME     target for config/ (default: ~/.config)
#   DOTFILES_MODE       copy|symlink — same as --copy / default
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
XDG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CLAUDE_HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

MODE="${DOTFILES_MODE:-symlink}"
DRY_RUN=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --copy|-c)    MODE=copy ;;
    --symlink|-s) MODE=symlink ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --force|-f)   FORCE=1 ;;
    --help|-h)    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  copy|symlink) ;;
  *) echo "invalid mode: $MODE (expected copy or symlink)" >&2; exit 2 ;;
esac

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
    log "backup    $dest -> $BACKUP_DIR/$(basename "$dest")"
    run mkdir -p "$BACKUP_DIR"
    run mv "$dest" "$BACKUP_DIR/$(basename "$dest")"
  fi
}

install_symlink() {
  local src="$1" dest="$2"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "ok        $dest (already linked)"
    return
  fi

  [ -e "$dest" ] || [ -L "$dest" ] || log "link      $dest"
  clear_dest "$dest"
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
log "target:   $CLAUDE_HOME, $XDG_HOME"
log "mode:     $MODE"
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

log ""
log "done."
