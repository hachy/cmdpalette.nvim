# cmdpalette.nvim

A Neovim plugin that provides a floating command-line window.

https://user-images.githubusercontent.com/1613863/211680141-0bfa36f4-8bf2-43aa-83dc-4be1d4787bc6.mov

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

### Keybindings

In normal mode

- `q`, `Esc`: Quit the current window
- `C-d`: Remove a command under the cursor from a cmdline-history

## Configuration

Below is a default options:

```lua
require("cmdpalette").setup({
  win = {
    height = 0.3,
    width = 0.8,
    border = "rounded",
    row_off = -2,
  },
  sign = {
    text = ":",
  },
  buf = {
    filetype = "vim",
    syntax = "vim",
  },
  delete_confirm = true,
},

```
