-- Rex plugin that opens shells in VS Code devcontainers and keeps splits and new tabs inside the same container.
local docker = require("devcontainer.docker")

local M = {}

local TERMINAL = "com.superlogical.terminal"

-- Defaults; setup{} merges one level deep, and a key set to false turns that binding off.
local defaults = {
  keys = {
    open = false,
    new_tab = { "cmd+t" },
    split_auto = { "cmd+enter" },
    split_right = { "cmd+d", "shift+cmd+right" },
    split_down = { "shift+cmd+d", "shift+cmd+down" },
    split_left = { "shift+cmd+left" },
    split_up = { "shift+cmd+up" },
  },
  -- Passed to docker exec; values must not contain spaces, because splits rebuild the command from ps output.
  env = { "TERM", "COLORTERM", "LANG=C.UTF-8" },
  -- nil picks VS Code's remoteUser; a string or function(container) overrides it.
  user = nil,
  -- nil picks zsh, then bash, then sh inside the container.
  shell = nil,
  -- Folders tried in order for the first shell; volume clones live in /workspaces/<project>.
  folders = function(c) return { "/workspaces/" .. c.project, "/workspaces" } end,
  -- Tab label for a container's tabs.
  label = function(c) return c.project end,
}

local opts = defaults

-- Returns a copy of base with override's fields on top, one level deep.
local function merge(base, override)
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(override or {}) do
    if type(v) == "table" and type(base[k]) == "table" and #v == 0 then
      out[k] = merge(base[k], v)
    else
      out[k] = v
    end
  end
  return out
end

-- Returns the container named in a `docker exec` argv, skipping options and their values.
local function container_of(argv)
  local takes_value = { ["-u"] = true, ["--user"] = true, ["-w"] = true, ["--workdir"] = true,
    ["-e"] = true, ["--env"] = true, ["--env-file"] = true, ["--detach-keys"] = true }
  local i = 3
  while argv[i] do
    local a = argv[i]
    if takes_value[a] then i = i + 2
    elseif a:sub(1, 1) == "-" then i = i + 1
    else return a end
  end
end

-- Returns the label for a container's tab, from its name.
local function label_for(name)
  for _, c in ipairs(docker.list() or {}) do
    if c.name == name then return opts.label(c) end
  end
  return name
end

-- Returns the process facts of a pane, or nil when it is not a terminal.
local function pane_process(block_id)
  local ok, p = pcall(rex.block.call, TERMINAL, "process", { block_id = block_id })
  if ok and type(p) == "table" and p.child then return p end
end

-- Returns terminal options that repeat a pane's `docker exec`, or keep the pane's folder otherwise.
local function follow(block_id)
  local p = pane_process(block_id)
  if not p then return {} end
  local argv = docker.exec_on_tty(p.child.pid)
  if argv then return { command = argv }, container_of(argv) end
  return { cwd = (p.foreground and p.foreground.cwd) or p.child.cwd }
end

-- Shows a window in the app that ran the action; the server's active window alone does not move the app's tab.
local function show(ctx, window_id)
  if not ctx.client_id then return end
  -- Asks only clients that offer session.select, so `rex do` from a terminal does not wait for a timeout.
  local ok, info = pcall(rex.call, "client.inspect", { client_id = ctx.client_id })
  local offers = false
  for _, a in ipairs(ok and type(info) == "table" and info.actions or {}) do
    if a.name == "session.select" then offers = true end
  end
  if not offers then return end
  local done, err = pcall(rex.call, "client.perform", { client_id = ctx.client_id, action = "session.select", timeout_ms = 2000,
    args = { session_id = ctx.session_id, window_id = window_id } })
  -- Rex.app refuses actions from the server until Remote Control is on, so say how to fix it.
  if not done and tostring(err):find("Remote Control", 1, true) then
    return "Opened in a new tab. To switch to it automatically, turn on Remote Control in Rex Settings > General."
  end
end

-- Opens a new tab with the given terminal options, labels it, and shows it.
local function new_tab(ctx, options, label)
  local created = rex.session.new_window{
    session_id = ctx.session_id,
    focus = true,
    layout = rex.layout.block{ flavor = TERMINAL .. ".shell", options = options },
  }
  if type(created) ~= "table" or not created.window_id then return end
  if label then
    pcall(rex.call, "session.set_window_label", { session_id = ctx.session_id, window_id = created.window_id, label = label })
  end
  return show(ctx, created.window_id)
end

-- Picks right or down for a best-fit split, from the pane's size in pixels.
local function best_fit(block_id)
  local ok, s = pcall(rex.block.call, TERMINAL, "size", { block_id = block_id })
  if not ok or type(s) ~= "table" or not s.columns then return "right" end
  return (s.columns * s.cell_width_px >= s.rows * s.cell_height_px) and "right" or "down"
end

-- Splits the pane; a pane inside a devcontainer opens the new pane in the same container.
local function split(ctx, direction)
  if direction == "auto" then direction = best_fit(ctx.block_id) end
  rex.session.new_split{
    anchor_id = ctx.block_id,
    direction = (direction == "left" or direction == "right") and "horizontal" or "vertical",
    side = (direction == "left" or direction == "up") and "before" or "after",
    layout = rex.layout.block{ flavor = TERMINAL .. ".shell", options = (follow(ctx.block_id)) },
  }
end

-- Builds the docker exec argv for a container's first shell.
local function exec_argv(c)
  local user = type(opts.user) == "function" and opts.user(c) or opts.user or docker.user(c.name)
  local dir, shell = docker.probe(c.name, user, opts.folders(c))
  local argv = { "docker", "exec", "-it", "-u", user, "-w", dir }
  for _, e in ipairs(opts.env) do argv[#argv + 1] = "-e"; argv[#argv + 1] = e end
  argv[#argv + 1] = c.name
  argv[#argv + 1] = opts.shell or shell
  argv[#argv + 1] = "-l"
  return argv
end

-- Lets the user pick a devcontainer (starting it if stopped) and opens a tab in it.
local function open(ctx)
  local list, err = docker.list()
  if not list then return err end
  if #list == 0 then return "No devcontainer found. Open one in VS Code first." end
  local c = list[1]
  if #list > 1 or not c.running then
    local items = {}
    for _, x in ipairs(list) do
      items[#items + 1] = { id = x.name, title = x.project, icon = "server",
        subtitle = x.running and x.name or (x.name .. " (stopped, starts on open)") }
    end
    local picked = rex.ui.pick{ title = "Open Devcontainer", items = items }
    if not picked then return end
    for _, x in ipairs(list) do if x.name == picked then c = x end end
  end
  if not c.running then
    local ok, why = docker.start(c.name)
    if not ok then return "Could not start " .. c.name .. ": " .. why end
  end
  return new_tab(ctx, { command = exec_argv(c) }, opts.label(c))
end

-- Registers the actions and binds their keys.
function M.setup(user_opts)
  opts = merge(defaults, user_opts)
  local actions = {
    { "devcontainer_open", "Open Devcontainer", open },
    { "devcontainer_new_tab", "New Tab (same container)", function(ctx)
      local options, name = follow(ctx.block_id)
      return new_tab(ctx, options, name and label_for(name))
    end },
  }
  for _, d in ipairs({ "auto", "right", "down", "left", "up" }) do
    actions[#actions + 1] = { "devcontainer_split_" .. d, "Split Pane " .. d .. " (same container)", function(ctx) split(ctx, d) end }
  end
  local key_of = { devcontainer_open = "open", devcontainer_new_tab = "new_tab" }
  for _, a in ipairs(actions) do
    local name, title, run = a[1], a[2], a[3]
    rex.action{ name = name, title = title, run = run }
    local keys = opts.keys[key_of[name] or name:gsub("^devcontainer_", "")]
    if type(keys) == "string" then keys = { keys } end
    for _, key in ipairs(keys or {}) do rex.bind(key, name) end
  end
end

return M
