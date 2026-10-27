#!/usr/bin/env bash
#
# Set up a new machine: install the essentials, then run install.sh.
#   macOS          Homebrew + Brewfile
#   Linux          apt, dnf or pacman, whichever the machine has
#   containers     same as Linux, but no Nerd Font (the host terminal renders fonts)
#
# Essentials: Claude Code, tmux, Node, ccstatusline, gh, lazygit, JetBrainsMono Nerd Font.
# After install.sh, it installs the Claude Code plugins that claude/settings.json enables.
# Anything already installed is skipped, so re-running is safe.
#
# Usage:
#   ./bootstrap.sh                # install tools, then ./install.sh
#   ./bootstrap.sh --dry-run      # show what would happen, change nothing
#   ./bootstrap.sh --copy         # any other option is passed on to install.sh
#
# Without a clone, pipe it from GitHub; it clones the repo, then runs from there:
#   curl -fsSL https://raw.githubusercontent.com/linhavo/dotfiles/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --dry-run
#
# Env:
#   DOTFILES_HOME   where to clone when piped (default: ~/.dotfiles)
#   DOTFILES_REPO   what to clone when piped (default: this repo on GitHub)
#
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/linhavo/dotfiles.git}"
# Piped from curl, BASH_SOURCE is empty and this resolves to the current directory.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
DRY_RUN=0
INSTALL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1; INSTALL_ARGS+=("$arg") ;;
    --help|-h)
      if [ -f "${BASH_SOURCE[0]:-}" ]; then sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      else echo "see the header of bootstrap.sh in $REPO_URL"
      fi
      exit 0 ;;
    *)            INSTALL_ARGS+=("$arg") ;;
  esac
done

log() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then log "  would run: $*"; else "$@"; fi; }
has() { command -v "$1" >/dev/null 2>&1; }

# Run as root when needed: directly if we are root, through sudo otherwise.
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"
as_root() { run ${SUDO:+$SUDO} "$@"; }

# ── Resolve the machine ──────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
IN_CONTAINER=0
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${REMOTE_CONTAINERS:-}" ] \
  || [ -n "${CODESPACES:-}" ] || [ -n "${DEVPOD:-}" ]; then
  IN_CONTAINER=1
fi

PKG=""
case "$OS" in
  Darwin) PKG=brew ;;
  Linux)
    if   has apt-get; then PKG=apt
    elif has dnf;     then PKG=dnf
    elif has pacman;  then PKG=pacman
    else echo "no supported package manager (apt, dnf, pacman) found" >&2; exit 1
    fi ;;
  *) echo "unsupported OS: $OS" >&2; exit 1 ;;
esac

log "machine:  $OS $ARCH, $PKG$([ "$IN_CONTAINER" -eq 1 ] && echo ', container')"
[ "$DRY_RUN" -eq 1 ] && log "(dry run — nothing will be changed)"
log ""

install_homebrew() {
  has brew && return
  log "install   Homebrew"
  run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Put brew on PATH for the rest of this script (Apple silicon, then Intel).
  if   [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ];    then eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# Install distro packages quietly; the output is shown only when the install fails.
pkg_install() {
  [ "$#" -gt 0 ] || return 0
  log "install   $*"
  if [ "$DRY_RUN" -eq 1 ]; then log "  would install with $PKG: $*"; return; fi
  local out
  out="$(mktemp)"
  if ! {
    case "$PKG" in
      apt)
        as_root env DEBIAN_FRONTEND=noninteractive apt-get update -q &&
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "$@" ;;
      dnf)    as_root dnf install -y -q --setopt=install_weak_deps=False "$@" ;;
      pacman) as_root pacman -Sy --needed --noconfirm "$@" ;;
    esac
  } >"$out" 2>&1; then
    cat "$out" >&2
    rm -f "$out"
    echo "package install failed: $*" >&2
    exit 1
  fi
  rm -f "$out"
}

# ── Fetch the repo when piped ────────────────
if [ ! -f "$DOTFILES_DIR/install.sh" ]; then
  target="${DOTFILES_HOME:-$HOME/.dotfiles}"

  # macOS ships a git stub that only prompts for the Command Line Tools; Homebrew installs them.
  if [ "$OS" = Darwin ]; then
    xcode-select -p >/dev/null 2>&1 || install_homebrew
  elif ! has git; then
    if [ "$PKG" = apt ]; then pkg_install git ca-certificates; else pkg_install git; fi
  fi

  if [ -d "$target/.git" ]; then
    log "update    $target"
    run git -C "$target" pull --ff-only || log "  (pull failed, using $target as it is)"
  else
    log "clone     $REPO_URL -> $target"
    run git clone "$REPO_URL" "$target"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log ""
    log "then run: $target/bootstrap.sh $*"
    exit 0
  fi
  log ""
  # Read from the terminal again, since stdin is still the curl pipe.
  if { : </dev/tty; } 2>/dev/null; then exec "$target/bootstrap.sh" "$@" </dev/tty; fi
  exec "$target/bootstrap.sh" "$@"
fi

# ── System packages ──────────────────────────
install_macos() {
  install_homebrew
  log "install   Brewfile"
  run brew bundle --no-upgrade --file="$DOTFILES_DIR/Brewfile"
}

install_linux() {
  # Ask only for what is missing, so an image that ships Node or git keeps its own.
  local pkgs=()
  has curl || pkgs+=(curl)
  has git  || pkgs+=(git)
  has tmux || pkgs+=(tmux)
  has node || pkgs+=(nodejs)
  has npm  || pkgs+=(npm)
  if ! has gh; then
    if [ "$PKG" = pacman ]; then pkgs+=(github-cli); else pkgs+=(gh); fi
  fi
  # lazygit is packaged by pacman and newer Debian/Ubuntu; elsewhere the release binary is used.
  if ! has lazygit; then
    case "$PKG" in
      pacman) pkgs+=(lazygit) ;;
      apt)    if apt-cache show lazygit >/dev/null 2>&1; then pkgs+=(lazygit); fi ;;
    esac
  fi
  # Without recommends, apt does not pull in CA certificates for curl and git.
  if [ "$PKG" = apt ] && [ "${#pkgs[@]}" -gt 0 ]; then pkgs+=(ca-certificates); fi

  if [ "${#pkgs[@]}" -eq 0 ]; then log "ok        system packages"; else pkg_install "${pkgs[@]}"; fi

  has lazygit || install_lazygit_release
  if [ "$IN_CONTAINER" -eq 1 ]; then
    log "skip      JetBrainsMono Nerd Font (container)"
  else
    install_nerd_font_linux
  fi
}

# Fall back to the lazygit release binary where the distro does not package it.
install_lazygit_release() {
  local arch version tmp
  case "$ARCH" in
    x86_64)        arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) log "skip      lazygit (no release for $ARCH)"; return ;;
  esac
  log "install   lazygit (GitHub release)"
  [ "$DRY_RUN" -eq 1 ] && { log "  would download lazygit for Linux_$arch into ~/.local/bin"; return; }
  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp" lazygit
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
}

install_nerd_font_linux() {
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if [ -d "$dir" ]; then log "ok        JetBrainsMono Nerd Font"; return; fi
  log "install   JetBrainsMono Nerd Font"
  [ "$DRY_RUN" -eq 1 ] && { log "  would download into $dir"; return; }
  mkdir -p "$dir"
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
    | tar -xJ -C "$dir"
  has fc-cache && fc-cache -f "$dir" >/dev/null
}

# ── Cross-platform tools ─────────────────────
install_claude() {
  if has claude; then log "ok        claude"; return; fi
  log "install   claude"
  if [ "$DRY_RUN" -eq 1 ]; then log "  would run: curl -fsSL https://claude.ai/install.sh | bash"; return; fi
  curl -fsSL https://claude.ai/install.sh | bash
}

install_ccstatusline() {
  if has ccstatusline; then log "ok        ccstatusline"; return; fi
  log "install   ccstatusline"
  # A system-wide npm prefix (e.g. /usr on apt) needs root to install globally.
  if [ -w "$(npm prefix -g 2>/dev/null || echo /nonexistent)" ]; then
    run npm install -g ccstatusline
  else
    as_root npm install -g ccstatusline
  fi
}

# Install the marketplace plugins that claude/settings.json enables; builtin ones need no install.
install_claude_plugins() {
  if ! has claude || ! has node; then log "skip      claude plugins (claude or node not on PATH)"; return; fi
  local wanted installed plugin
  wanted="$(node -e '
    const s = require(process.argv[1]);
    for (const [id, on] of Object.entries(s.enabledPlugins || {}))
      if (on && !id.endsWith("@builtin")) console.log(id);
  ' "$DOTFILES_DIR/claude/settings.json")"
  installed="$(claude plugin list --json 2>/dev/null | node -e '
    let d = ""; process.stdin.on("data", c => d += c).on("end", () => {
      for (const p of JSON.parse(d || "[]")) if (p.scope === "user") console.log(p.id);
    });
  ' || true)"
  for plugin in $wanted; do
    if printf '%s\n' "$installed" | grep -qxF "$plugin"; then log "ok        $plugin"; continue; fi
    log "install   $plugin"
    run claude plugin install "$plugin"
  done
}

if [ "$OS" = Darwin ]; then install_macos; else install_linux; fi
install_claude
install_ccstatusline

log ""
# The +-guard keeps an empty array working under set -u on macOS bash 3.2.
"$DOTFILES_DIR/install.sh" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}

# Runs after install.sh, so plugin installs update the settings.json this repo placed.
log ""
install_claude_plugins
