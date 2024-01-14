if vim.g.loaded_cmdpalette == 1 then
  return
end
vim.g.loaded_cmdpalette = 1

vim.api.nvim_create_user_command("Cmdpalette", require("cmdpalette").open, {})

vim.keymap.set("n", "<Plug>(cmdpalette)", "<Cmd>Cmdpalette<CR>", { silent = true })
