# devcontainer.rex

A [Rex](https://www.superlogical.com/rex) plugin for VS Code devcontainers, including volume clones.

- **Open Devcontainer** lists your devcontainers, starts a stopped one, and opens a tab in its project folder.
- Splits and new tabs follow the focused pane: in a container they open in the same container, elsewhere they keep the folder.
- Tabs are labelled with the project name.

Each pane is one `docker exec`. Nothing runs in the container or on the Mac besides that.

## Install

1. Put this folder at `~/.config/rex/devcontainer`.
2. Add this line to `~/.config/rex/init.lua`:

   ```lua
   require("devcontainer").setup{}
   ```

3. Run `rex config reload`.

## Use

- Press `shift+cmd+p` and run **Open Devcontainer**, or run `rex do devcontainer_open`.
- Split with Rex's usual keys: `cmd+enter`, `cmd+d`, `shift+cmd+d`, `shift+cmd+arrow`.
- Open a tab with `cmd+t`.

## Options

Every option is optional. These are the defaults:

```lua
require("devcontainer").setup{
  keys = {
    open = false,                                  -- a key such as "shift+cmd+o"
    new_tab = { "cmd+t" },
    split_auto = { "cmd+enter" },
    split_right = { "cmd+d", "shift+cmd+right" },
    split_down = { "shift+cmd+d", "shift+cmd+down" },
    split_left = { "shift+cmd+left" },
    split_up = { "shift+cmd+up" },
  },
  env = { "TERM", "COLORTERM", "LANG=C.UTF-8" },   -- docker exec -e values
  user = nil,                                      -- string or function(c); nil uses VS Code's remoteUser
  shell = nil,                                     -- nil uses zsh, then bash, then sh
  folders = function(c) return { "/workspaces/" .. c.project, "/workspaces" } end,
  label = function(c) return c.project end,
}
```

`c` is `{ name, project, running }`. Set a key to `false` to keep Rex's own binding.

## How it works

- Devcontainers are the containers with the label `devcontainer.local_folder`. This skips VS Code's volume-clone helper container.
- The user is the last `remoteUser` in the label `devcontainer.metadata`, else the image user.
- A split finds the `docker exec` on the pane's tty with `ps` and runs the same command. Rex starts panes through `login`, so `docker` is never the pane's direct child.
- After opening a tab, the plugin asks the app to show it with `session.select`. The server's active window alone does not change the app's tab.
- Rex.app accepts that request only with **Remote Control** on (Settings > General). Without it, the tab opens in the background and the action says so.

## Limits

- `docker exec` arguments must not contain spaces, because splits rebuild the command from `ps` output.
- A container rebuild or restart ends its shells.
- Rex cannot use a container as a host, so `rex -S`, `rex cp` and `rex forward` do not reach it.
- In Rex's Lua, `rex.exec{...}.stdout` misparses, so the code stores each result in a local first.
