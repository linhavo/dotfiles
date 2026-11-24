#!/usr/bin/env python3
"""Status line wrapper: saves the context used for World of Codecraft's health bar, then runs ccstatusline.

Inside Herdr (HC_TERMINAL_ID set) it writes ~/.local/state/world-of-codecraft/<terminal>-ctx.json:
  {"used": <context tokens in use>, "size": <context window tokens>, "t": <ms>}
The mod turns tokens into health against its own limits.
The status line input passes through to ccstatusline unchanged, so the status line looks the same.
"""
import json, os, subprocess, sys, time

raw = sys.stdin.read()


def used_tokens(cw):
    """Context tokens in use (input + cache), or None when the input doesn't say."""
    cu = cw.get("current_usage") or {}
    parts = [cu.get(k) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")]
    if any(isinstance(p, (int, float)) for p in parts):
        return int(sum(p for p in parts if isinstance(p, (int, float))))
    if isinstance(cw.get("total_input_tokens"), (int, float)):
        return int(cw["total_input_tokens"])
    return None


term = os.environ.get("HC_TERMINAL_ID")
if term:
    try:
        cw = json.loads(raw).get("context_window") or {}
        used = used_tokens(cw)
        # 0 means no usage yet (right after /compact or a new session), so the last real count stays
        if used:
            d = os.path.expanduser("~/.local/state/world-of-codecraft")
            os.makedirs(d, exist_ok=True)
            p = os.path.join(d, f"{term}-ctx.json")
            with open(p + ".tmp", "w") as f:
                json.dump({"used": used, "size": cw.get("context_window_size"), "t": int(time.time() * 1000)}, f)
            os.replace(p + ".tmp", p)
    except Exception:
        pass

sys.exit(subprocess.run(["ccstatusline"], input=raw, text=True).returncode)
