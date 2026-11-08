# Decisions

## Plain symlinks, not chezmoi

Decided 2026-11-08.
chezmoi templates would cover per-machine values, but at two costs:

- Its source tree encodes names (`dot_zshrc`, `private_dot_config/`), so the repo is hard to read and edit.
- Templated files cannot be symlinks, so the files that differ per machine lose in-place editing.

Instead, profiles layer per-machine values on top of the shared config (see the README).
Revisit chezmoi if secrets must go into config files.

## Profiles cover only files that can include another file

Git (`[include]`) and zsh (`source`) load a profile file.
JSON configs (`claude/settings.json`, ccstatusline) have no include, so they stay shared.
The only per-machine difference in `claude/settings.json` is the `linear` plugin, so it stays enabled everywhere.

If a JSON config must differ later, choose one of these:

- Swap the whole file per profile; it stays a symlink but duplicates content.
- Merge base and profile with `jq` at install time; the result is a copy, so edits do not reach the repo.

Generate `claude/settings.json` with `jq` if Claude Code keeps writing into the symlinked file.

## Containers take the host's git identity

VS Code copies the host `~/.gitconfig` into a devcontainer, and it overrides the profile.
So the `container` profile sets no identity, and a work laptop's containers commit with the work email.
Profile choice for a container lives on the host, in a VS Code profile's settings, never in the project's repo.

## VS Code settings stay out of this repo

`settings.json` has no include, VS Code rewrites it, it is JSONC, and Settings Sync already manages it.
One per-machine setting does not justify tracking it.

## Deferred

- tmux joins profiles through `source-file -q` once it needs per-machine values.
- `includeIf "gitdir:~/work/"` picks the git identity per repo, if work and personal repos share a machine.
