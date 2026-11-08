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
  git/            # shared git config, global hooks (gitleaks pre-commit)
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
zsh-syntax-highlighting, pnpm-shell-completion, gitleaks and the JetBrainsMono Nerd Font.
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

### Devcontainers

```jsonc
// .devcontainer/devcontainer.json
"postCreateCommand": "git clone https://github.com/<you>/dotfiles ~/.dotfiles && ~/.dotfiles/bootstrap.sh --copy"
```

`bootstrap.sh` installs starship and the zsh plugins that `.zshrc` expects; `install.sh` alone does not.
Devcontainer images often ship an oh-my-zsh `~/.zshrc`, which the installer backs up.
To keep oh-my-zsh (e.g. its git aliases), move its lines into `~/.zshrc.local`; starship still owns the prompt.

Set `CLAUDE_CONFIG_DIR` if the target is not `~/.claude`, or
`DOTFILES_MODE=copy` to pick the mode by environment rather than by flag.

## Secret scan (gitleaks)

Every commit on a machine with these dotfiles runs a gitleaks scan of the staged changes.
The hook comes from dotfiles, so no repo needs its own setup.

- `config/git/config` sets `core.hooksPath = ~/.config/git/hooks`.
- `config/git/hooks/pre-commit` runs `gitleaks git --pre-commit --staged --redact --verbose --no-banner`.
- A leak blocks the commit. The output shows the file, line and rule, with the secret redacted.
- A global `core.hooksPath` replaces each repo's `.git/hooks`. So the global hook also runs the repo's `.git/hooks/pre-commit` when it is executable. The commit fails if either fails.
- If gitleaks is not installed, the hook prints a warning and lets the commit through. This keeps a fresh machine usable before `bootstrap.sh`.

`bootstrap.sh` installs the version in `GITLEAKS_VERSION`:

- macOS: Homebrew. Homebrew carries only its current formula, so the bootstrap reports when that differs from the pin.
- Linux: the release binary for x86_64 or arm64, into `~/.local/bin`. The bootstrap verifies it against the release's checksums file and aborts on a mismatch.

Check a machine with:

```sh
gitleaks version                  # the pinned version
git config --get core.hooksPath   # ~/.config/git/hooks
```

### False positives

Fix a false positive in the repo, so the fix holds for every clone:

1. Add `gitleaks:allow` in a comment on the line that triggers the finding.
2. Or add the finding's `Fingerprint` (e.g. `config.env:github-pat:1`) as a line in `.gitleaksignore` at the repo root.

Last resort: `git commit --no-verify` skips the scan and every other pre-commit hook for that commit.
Use it only when you are sure the finding is not a secret.

### Limits

- Only `pre-commit` chains to the repo. Other hooks in `.git/hooks` (e.g. `commit-msg`, `pre-push`) do not run while the global `core.hooksPath` is set.
- A repo that sets its own `core.hooksPath` (e.g. husky) overrides the global one, and the gitleaks hook does not run there.
- The pre-commit framework (`pre-commit install`) refuses to install while `core.hooksPath` is set.

## Notes

tmux reads `~/.tmux.conf` before `~/.config/tmux/tmux.conf`.
Remove `~/.tmux.conf` so the tracked config takes effect.

Git identity stays out of this public repo, in an untracked `~/.gitconfig`.
On a new machine, set it once:

```sh
git config --global user.name "Your Name"
git config --global user.email you@example.com
```

Machine-local shell settings and secrets go in an untracked `~/.zshrc.local`, which `.zshrc` sources.
Installers that append to `~/.zshrc` (e.g. `pnpm setup`) write into this repo, so move such lines there.

The status line needs `ccstatusline` on `PATH` (`npm i -g ccstatusline`).

`~/.claude/plugins` is deliberately not tracked — Claude Code manages that
directory itself, so keeping it under version control fights with plugin
installs and updates.
