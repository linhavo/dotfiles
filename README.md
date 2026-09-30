# dotfiles

Personal dotfiles, starting with Claude Code configuration.

## Layout

```
claude/           # installed into ~/.claude
  CLAUDE.md       # global instructions for every project
  settings.json   # model, effort, status line, plugins
  agents/         # custom subagents (implementer)
  commands/       # slash commands
  hooks/          # hook scripts
  output-styles/  # output styles
  skills/         # skills (handoff)
config/           # installed into ~/.config
  ccstatusline/   # status line layout
install.sh        # puts everything in place
```

Anything you add at the top level of `claude/` (e.g. `settings.json`,
`CLAUDE.md`) is picked up automatically — the installer walks every entry.

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
Copy mode merges into existing directories, so entries already in
`~/.claude/skills` that this repo does not carry are left alone.

Anything replaced is moved to `~/.claude/dotfiles-backup/<timestamp>/`
unless `--force` is passed.

### Devcontainers

```jsonc
// .devcontainer/devcontainer.json
"postCreateCommand": "git clone https://github.com/<you>/dotfiles ~/.dotfiles && ~/.dotfiles/install.sh --copy"
```

Set `CLAUDE_CONFIG_DIR` if the target is not `~/.claude`, or
`DOTFILES_MODE=copy` to pick the mode by environment rather than by flag.

## Notes

The status line needs `ccstatusline` on `PATH` (`npm i -g ccstatusline`).

`~/.claude/plugins` is deliberately not tracked — Claude Code manages that
directory itself, so keeping it under version control fights with plugin
installs and updates.
