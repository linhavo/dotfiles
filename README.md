# dotfiles

Personal dotfiles, starting with Claude Code configuration.

## Layout

```
claude/           # installed into ~/.claude
  CLAUDE.md       # global instructions for every project
  settings.json   # model, permissions, effort, status line, plugins
  agents/         # custom subagents (explorer, implementer)
  commands/       # slash commands
  hooks/          # hook scripts
  output-styles/  # output styles
  skills/         # skills (card, handoff)
config/           # installed into ~/.config
  ccstatusline/   # status line layout
  git/            # shared git config
  tmux/           # tmux.conf (tmux ≥ 3.1 reads ~/.config/tmux/tmux.conf)
Brewfile          # macOS packages for bootstrap.sh
bootstrap.sh      # installs the essentials, then runs install.sh
install.sh        # puts everything in place
```

Anything you add at the top level of `claude/` (e.g. `settings.json`,
`CLAUDE.md`) is picked up automatically — the installer walks every entry.

## New machine

Without a clone (it clones into `~/.dotfiles`, or `$DOTFILES_HOME`):

```sh
curl -fsSL https://raw.githubusercontent.com/linhavo/dotfiles/main/bootstrap.sh | bash
```

From a clone:

```sh
git clone git@github.com:linhavo/dotfiles.git && cd dotfiles
./bootstrap.sh --dry-run   # preview
./bootstrap.sh             # install tools, then run install.sh
```

`bootstrap.sh` detects the OS and package manager, then installs Claude Code,
tmux, Node, ccstatusline, gh, lazygit and the JetBrainsMono Nerd Font.
It uses Homebrew on macOS and apt, dnf or pacman on Linux.
It skips tools that are already installed, and skips the font in containers.
Other options, such as `--copy`, pass through to `install.sh`.

## Install

```sh
./install.sh --dry-run   # preview, change nothing
./install.sh             # symlink (default)
./install.sh --copy      # copy instead
./install.sh --force     # skip backups, replace outright
```

Two modes:

| | symlink (default) | copy (`--copy`) |
|---|---|---|
| Edits in `~/.claude` | land in the repo, show up in `git status` | are local only, lost on rebuild |
| Repo must stay put | yes — moving it leaves dangling links | no |
| Use for | your own machine | devcontainers, cloud sessions, images |

Both are idempotent and safe to re-run, including switching between modes.
Both merge into existing directories rather than clobbering them, so entries
already in `~/.claude/skills` that this repo does not carry (e.g. the
Claude Code-managed `synced/`) are left alone.

Anything replaced is moved to `~/.claude/dotfiles-backup/<timestamp>/<original path>`
unless `--force` is passed.

### Devcontainers

```jsonc
// .devcontainer/devcontainer.json
"postCreateCommand": "git clone https://github.com/<you>/dotfiles ~/.dotfiles && ~/.dotfiles/install.sh --copy"
```

Set `CLAUDE_CONFIG_DIR` if the target is not `~/.claude`, or
`DOTFILES_MODE=copy` to pick the mode by environment rather than by flag.

## Notes

tmux reads `~/.tmux.conf` before `~/.config/tmux/tmux.conf`.
Remove `~/.tmux.conf` so the tracked config takes effect.

Git identity stays out of this public repo, in an untracked `~/.gitconfig`.
On a new machine, set it once:

```sh
git config --global user.name "Your Name"
git config --global user.email you@example.com
```

The status line needs `ccstatusline` on `PATH` (`npm i -g ccstatusline`).

`~/.claude/plugins` is deliberately not tracked — Claude Code manages that
directory itself, so keeping it under version control fights with plugin
installs and updates.
