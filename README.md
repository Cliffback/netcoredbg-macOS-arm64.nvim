# Neovim plugin to implement netcoredbg on arm64 macOS

Since the official [netcoredbg repo](https://github.com/Samsung/netcoredbg) has no native macOS arm64 build, I built it myself and created this simple plugin to integrate it with nvim-dap.

The compiled build can also be downloaded from the releases.

I'll try to keep up to date with new releases, but the update script can also do it manually.

### Install
Lazy
```lua
  {
    "Cliffback/netcoredbg-macOS-arm64.nvim",
    dependencies = { "mfussenegger/nvim-dap" }
  }
```

### Setup
```lua
    require('netcoredbg-macOS-arm64').setup(require('dap'))
```
