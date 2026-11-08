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
home/             # installed into ~
  .zshrc          # history, completion (incl. pnpm), autosuggestions, highlighting, starship, pnpm PATH
Brewfile          # macOS packages for bootstrap.sh
bootstrap.sh      # installs the essentials, then runs install.sh
install.sh        # puts everything in place
```

Anything you add at the top level of `claude/`, `config/` or `home/` (e.g.
`claude/settings.json`, `home/.zshrc`) is picked up automatically — the installer walks every entry.

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

`bootstrap.sh` detects the OS and package manager, then installs Claude Code, zsh,
tmux, Node, ccstatusline, gh, lazygit, starship, zsh-autosuggestions,
zsh-syntax-highlighting, pnpm-shell-completion and the JetBrainsMono Nerd Font.
It uses Homebrew on macOS and apt, dnf or pacman on Linux.
It skips tools that are already installed, and skips the font in containers.
On Linux, it makes zsh the login shell, so new terminals and tmux load `.zshrc`.
Other options, such as `--copy`, pass through to `install.sh`.
After `install.sh`, it installs the Claude Code plugins that `claude/settings.json` enables.

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
| Edits in `~/.claude`, `~/.config` or `~/.zshrc` | land in the repo, show up in `git status` | are local only, lost on rebuild |
| Repo must stay put | yes — moving it leaves dangling links | no |
| Use for | your own machine | devcontainers, cloud sessions, images |

Both are idempotent and safe to re-run, including switching between modes.
Both merge into existing directories rather than clobbering them, so entries
already in `~/.claude/skills` that this repo does not carry (e.g. the
Claude Code-managed `synced/`) are left alone.

Anything replaced is moved to `~/.claude/dotfiles-backup/<timestamp>/<original path>`
unless `--force` is passed, for every target — e.g. `~/.zshrc` goes to `~/.claude/dotfiles-backup/<timestamp>/Users/<you>/.zshrc`.

### Profiles

A profile holds only what differs per machine; it loads on top of the shared config.
Git loads `profiles/<name>/gitconfig` through `[include]`, and `.zshrc` sources `profiles/<name>/zshrc`.
Untracked `~/.gitconfig` and `~/.zshrc.local` load last, so they override the profile.

```sh
./install.sh --profile work   # pick once; later runs reuse the saved choice
```

`install.sh` picks the profile in this order:

1. `--profile <name>` or `DOTFILES_PROFILE`.
2. The saved choice in `~/.config/dotfiles/profile-name`.
3. `container`, when it detects a container.

Without any of these, it installs no profile.
The reasons behind this layout are in [docs/decisions.md](docs/decisions.md).

### Devcontainers

Set the dotfiles in VS Code user settings, so no project repo needs a change:

```jsonc
// VS Code user settings on the host
"dotfiles.repository": "linhavo/dotfiles",
"dotfiles.installCommand": "bootstrap.sh"
```

VS Code clones the repo into each new container and runs the command.
Without `installCommand`, it runs `install.sh`, which skips the tools.
Inside a container, `install.sh` picks the `container` profile.

The `container` profile sets no git identity.
VS Code copies the host `~/.gitconfig` into the container, so containers commit as the host does.

To use the `work` profile in containers, put `"dotfiles.installCommand": "bootstrap.sh --profile work"` in a work VS Code profile.
The `dotfiles.*` settings are machine-scoped, so a VS Code profile can hold them and Settings Sync skips them.
This assumes `installCommand` passes arguments through; that is not confirmed yet.

For a project you own, a `postCreateCommand` works too:

```jsonc
// .devcontainer/devcontainer.json
"postCreateCommand": "git clone https://github.com/<you>/dotfiles ~/.dotfiles && ~/.dotfiles/bootstrap.sh --copy"
```

`bootstrap.sh` installs starship and the zsh plugins that `.zshrc` expects; `install.sh` alone does not.
Devcontainer images often ship an oh-my-zsh `~/.zshrc`, which the installer backs up.
To keep oh-my-zsh (e.g. its git aliases), move its lines into `~/.zshrc.local`; starship still owns the prompt.

Set `CLAUDE_CONFIG_DIR` if the target is not `~/.claude`, or
`DOTFILES_MODE=copy` to pick the mode by environment rather than by flag.

## Notes

tmux reads `~/.tmux.conf` before `~/.config/tmux/tmux.conf`.
Remove `~/.tmux.conf` so the tracked config takes effect.

Git identity comes from the profile's `gitconfig`.
This repo is public, so anything in a profile is public too.
Put an identity you want to keep private in the untracked `~/.gitconfig`; it overrides the profile.

Machine-local shell settings and secrets go in an untracked `~/.zshrc.local`, which `.zshrc` sources.
Installers that append to `~/.zshrc` (e.g. `pnpm setup`) write into this repo, so move such lines there.

The status line needs `ccstatusline` on `PATH` (`npm i -g ccstatusline`).

`~/.claude/plugins` is deliberately not tracked — Claude Code manages that
directory itself, so keeping it under version control fights with plugin
installs and updates.
