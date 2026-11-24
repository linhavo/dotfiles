#!/usr/bin/env python3
"""Status-line wrapper: records context usage for the World of Codecraft health bar, then runs ccstatusline.

Inside Herdr (HC_TERMINAL_ID set) it writes ~/.local/state/world-of-codecraft/<terminal>-ctx.json as
{"used", "size", "t"}. Hooks do not receive context usage, so the status line is the only source.
"""
import json, os, subprocess, sys, time

raw = sys.stdin.buffer.read()

# Write the context file only inside Herdr; never let a failure break the status line.
term = os.environ.get("HC_TERMINAL_ID")
if term:
    try:
        cw = json.loads(raw).get("context_window") or {}
        cur = cw.get("current_usage") or {}
        used = sum(int(cur.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
        state = os.path.expanduser("~/.local/state/world-of-codecraft")
        os.makedirs(state, exist_ok=True)
        path = os.path.join(state, f"{term}-ctx.json")
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"used": used, "size": cw.get("context_window_size"), "t": int(time.time() * 1000)}, f)
        os.replace(tmp, path)
    except Exception:
        pass

# Hand the same input to the real status line and pass its output through.
res = subprocess.run(["ccstatusline"], input=raw, stdout=subprocess.PIPE)
sys.stdout.buffer.write(res.stdout)
sys.exit(res.returncode)
