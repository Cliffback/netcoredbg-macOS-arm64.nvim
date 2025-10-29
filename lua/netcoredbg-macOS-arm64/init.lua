local M = {}

-- Get plugin install directory
local function get_plugin_directory()
  local str = debug.getinfo(1, "S").source:sub(2)
  str = str:match("(.*/)")
  return str:gsub("/[^/]+/[^/]+/$", "/")
end

local plugin_directory = get_plugin_directory()
local netcoredbg_path = plugin_directory .. 'netcoredbg/netcoredbg'

-- Check if file exists
local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

-- Read .env file into a Lua table
local function load_env_file(path)
  local env = {}
  local file = io.open(path, "r")
  if not file then return env end
  for line in file:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
    if key and value then
      value = value:gsub('^"(.*)"$', '%1') -- strip double quotes
      value = value:gsub("^'(.*)'$", '%1') -- strip single quotes
      env[key] = value
    end
  end
  file:close()
  return env
end

-- Get current file's directory name
local function getCurrentFileDirName()
  local fullPath = vim.fn.expand('%:p:h')
  return fullPath:match("([^/\\]+)$")
end

-- Find DLL build path
local function get_dll_path()
  local debugPath = vim.fn.expand('%:p:h') .. '/bin/Debug'
  if not file_exists(debugPath) then
    return vim.fn.getcwd()
  end
  local command = 'find "' .. debugPath .. '" -maxdepth 1 -type d -name "*net*" -print -quit'
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  result = result:gsub("[\r\n]+$", "")
  if result == "" then
    return debugPath
  else
    local potentialDllPath = result .. '/' .. getCurrentFileDirName() .. '.dll'
    if file_exists(potentialDllPath) then
      return potentialDllPath
    else
      return result .. '/'
    end
  end
end

M.setup = function()
  local dap = require("dap")
  -- 1. Load .env if exists
  local env_vars = {}
  local env_path = vim.fn.getcwd() .. "/.env"
  if vim.loop.fs_stat(env_path) then
    env_vars = load_env_file(env_path)
  end

  -- 2. Required keys that should prompt if missing
  local required_envs = {
    ASPNETCORE_ENVIRONMENT = "Development",
    ASPNETCORE_URL = "http://localhost:5000",
  }

  for key, default in pairs(required_envs) do
    if not env_vars[key] or env_vars[key] == "" then
      env_vars[key] = function()
        return vim.fn.input(key .. ": ", default)
      end
    end
  end

  -- 3. Set up DAP adapter
  dap.adapters.coreclr = {
    type = 'executable',
    command = netcoredbg_path,
    args = { '--interpreter=vscode' }
  }
  
  dap.adapters.netcoredbg = {
	  type = "executable",
	  command = netcoredbg_path,
	  args = { "--interpreter=vscode" },
  }

  -- 4. Register C# configuration
  dap.configurations.cs = {
    {
      type = 'coreclr',
      name = 'NetCoreDbg: Launch',
      request = 'launch',
      cwd = '${fileDirname}',
      program = function()
        return vim.fn.input('Path to dll', get_dll_path(), 'file')
      end,
      env = env_vars, -- includes .env values + interactive prompts
    },
  }
end

return M
