#!/usr/bin/env python3
"""Status line wrapper: saves the context left for World of Codecraft's health bar, then runs ccstatusline.

Inside Herdr (HC_TERMINAL_ID set) it writes ~/.local/state/world-of-codecraft/<terminal>-ctx.json:
  {"left": <percent of the context window still free, 0..100>, "t": <ms>}
The status line input passes through to ccstatusline unchanged, so the status line looks the same.
"""
import json, os, subprocess, sys, time

raw = sys.stdin.read()


def left_percent(ev):
    """Percent of the context window still free, or None when the input doesn't say."""
    cw = ev.get("context_window") or {}
    if isinstance(cw.get("remaining_percentage"), (int, float)):
        return cw["remaining_percentage"]
    if isinstance(cw.get("used_percentage"), (int, float)):
        return 100 - cw["used_percentage"]
    return None


term = os.environ.get("HC_TERMINAL_ID")
if term:
    try:
        left = left_percent(json.loads(raw))
        if left is not None:
            d = os.path.expanduser("~/.local/state/world-of-codecraft")
            os.makedirs(d, exist_ok=True)
            p = os.path.join(d, f"{term}-ctx.json")
            with open(p + ".tmp", "w") as f:
                json.dump({"left": max(0, min(100, round(left, 1))), "t": int(time.time() * 1000)}, f)
            os.replace(p + ".tmp", p)
    except Exception:
        pass

sys.exit(subprocess.run(["ccstatusline"], input=raw, text=True).returncode)
