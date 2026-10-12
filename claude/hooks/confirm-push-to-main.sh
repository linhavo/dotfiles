#!/usr/bin/env bash
# PreToolUse hook: asks for confirmation when a Bash `git push` targets the default branch.
set -o pipefail

cmd=$(jq -r '.tool_input.command // empty')
[[ "$cmd" == *"git"*"push"* ]] || exit 0

# Default branch from origin/HEAD, falling back to main.
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default#origin/}
default=${default:-main}
current=$(git branch --show-current 2>/dev/null)

ask() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

# Check each `git push` segment of a chained command separately.
while IFS= read -r seg; do
  [[ "$seg" =~ git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]].*)?$ ]] || continue
  read -ra args <<< "${BASH_REMATCH[2]}"

  positional=()
  for a in "${args[@]}"; do
    case "$a" in
      --all|--mirror) ask "git push $a includes '$default'. Push to a branch and open a PR instead?" ;;
      -*) ;;
      *) positional+=("$a") ;;
    esac
  done

  # No refspec pushes the current branch.
  if (( ${#positional[@]} <= 1 )); then
    [[ "$current" == "$default" ]] && ask "This pushes to '$default'. Push to a branch and open a PR instead?"
    continue
  fi

  for ref in "${positional[@]:1}"; do
    dest=${ref##*:}
    dest=${dest#+}
    dest=${dest#refs/heads/}
    [[ "$dest" == HEAD ]] && dest=$current
    [[ "$dest" == "$default" ]] && ask "This pushes to '$default'. Push to a branch and open a PR instead?"
  done
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
