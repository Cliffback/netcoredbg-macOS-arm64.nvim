-- myplugin/init.lua
local M = {}


local function get_plugin_directory()
  local str = debug.getinfo(1, "S").source:sub(2)
  str = str:match("(.*/)")                 -- Get the directory of the current file
  return str:gsub("/[^/]+/[^/]+/$", "/")   -- Go up two directories
end

local plugin_directory = get_plugin_directory()
local netcoredbg_path = plugin_directory .. 'bin/netcoredbg'


M.setup = function(dap)
  dap.adapters.coreclr = {
    type = 'executable',
    command = netcoredbg_path,
    args = { '--interpreter=vscode' }
  }

  local function getCurrentFileDirName()
    local fullPath = vim.fn.expand('%:p:h')      -- Get the full path of the directory containing the current file
    local dirName = fullPath:match("([^/\\]+)$") -- Extract the directory name
    return dirName
  end

  local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
      io.close(f)
      return true
    else
      return false
    end
  end

  local function get_dll_path()
    local debugPath = vim.fn.expand('%:p:h') .. '/bin/Debug'
    if not file_exists(debugPath) then
      return vim.fn.getcwd()
    end
    local command = 'find "' .. debugPath .. '" -maxdepth 1 -type d -name "*net*" -print -quit'
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    result = result:gsub("[\r\n]+$", "") -- Remove trailing newline and carriage return
    if result == "" then
      return debugPath
    else
      local potentialDllPath = result .. '/' .. getCurrentFileDirName() .. '.dll'
      if file_exists(potentialDllPath) then
        return potentialDllPath
      else
        return result == "" and debugPath or result .. '/'
      end
      --        return result .. '/' -- Adds a trailing slash if a net folder is found
    end
  end

  dap.configurations.cs = {
    {
      type = 'coreclr',
      name = 'NetCoreDbg: Launch',
      request = 'launch',
      cwd = '${fileDirname}',
      program = function()
        return vim.fn.input('Path to dll', get_dll_path(), 'file')
      end,
    },
  }
end

return M
