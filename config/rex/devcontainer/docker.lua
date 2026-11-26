-- Docker queries for the devcontainer plugin; every function shells out through rex.exec.
local M = {}

-- Runs a command and returns its stdout, or nil and stderr when it fails.
-- Each rex.exec result goes into a local first, because rex.exec{...}.stdout misparses in Rex's Lua.
local function run(argv)
  local r = rex.exec(argv)
  if not r.ok then return nil, (r.stderr ~= "" and r.stderr) or ("exit " .. tostring(r.code)) end
  return r.stdout or ""
end

-- Returns every devcontainer VS Code made (running first), or nil and a reason when Docker is unreachable.
-- The label devcontainer.local_folder marks real devcontainers and skips VS Code's volume-clone helper.
function M.list()
  local out, err = run{ "docker", "ps", "-a", "--filter", "label=devcontainer.local_folder",
    "--format", '{{.Names}}\t{{.State}}\t{{.Label "devcontainer.local_folder"}}' }
  if not out then return nil, "Docker is not reachable: " .. err end
  local list = {}
  for name, state, folder in out:gmatch("([^\t\n]+)\t([^\t\n]*)\t([^\n]*)") do
    list[#list + 1] = { name = name, running = state == "running", project = folder:match("[^/]+$") or name }
  end
  table.sort(list, function(a, b)
    if a.running ~= b.running then return a.running end
    return a.project < b.project
  end)
  return list
end

-- Starts a stopped container and returns true, or false and a reason.
function M.start(name)
  local out, err = run{ "docker", "start", name }
  if not out then return false, err end
  return true
end

-- Returns the user VS Code logs in as: the last remoteUser in the metadata, else the image user, else root.
function M.user(name)
  local meta = run{ "docker", "inspect", name, "--format", '{{index .Config.Labels "devcontainer.metadata"}}' } or ""
  local user
  for u in meta:gmatch('"remoteUser":"([^"]*)"') do user = u end
  if user and user ~= "" then return user end
  local image = run{ "docker", "inspect", name, "--format", "{{.Config.User}}" } or ""
  return image:match("%S+") or "root"
end

-- Returns the first folder that exists in the container, and its best login shell, in one docker exec.
function M.probe(name, user, folders)
  local script = 'for d in "$@"; do [ -d "$d" ] && { echo "$d"; break; }; done; echo; command -v zsh || command -v bash || echo sh'
  local argv = { "docker", "exec", "-u", user, name, "sh", "-c", script, "sh" }
  for _, f in ipairs(folders) do argv[#argv + 1] = f end
  local out = run(argv) or ""
  local dir, shell = out:match("^([^\n]*)\n+([^\n]+)")
  if not shell then dir, shell = nil, out:match("([^\n]+)") end
  return (dir ~= "" and dir) or "/", shell or "sh"
end

-- Returns the argv of a `docker exec` running on a process's tty; Rex wraps panes in login, so the tty is searched.
function M.exec_on_tty(pid)
  local tty = (run{ "ps", "-o", "tty=", "-p", tostring(pid) } or ""):match("%S+")
  if not tty or tty == "??" then return nil end
  for line in (run{ "ps", "-t", tty, "-o", "args=" } or ""):gmatch("[^\n]+") do
    if line:match("^%S*docker exec ") then
      local argv = {}
      for word in line:gmatch("%S+") do argv[#argv + 1] = word end
      argv[1] = "docker" -- ps shows login shells as "-docker"
      return argv
    end
  end
end

return M
