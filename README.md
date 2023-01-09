# cmdpalette.nvim

A Neovim plugin that provides a floating command-line window.

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'hachy/cmdpalette.nvim'
```

## Usage

```lua
require("cmdpalette").setup({})
```

Use the `Cmdpalette` command or call it in your own keybinding.

```lua
vim.keymap.set("n", ":", "<Cmd>Cmdpalette<CR>")
```

## Configuration

Below is a default options:

```lua
require("cmdpalette").setup({
  win = {
    height = 0.3,
    width = 0.8,
    border = "rounded",
  },
  sign = {
    text = ":",
  },
  buf = {
    filetype = "vim",
    syntax = "vim",
  },
},

```
