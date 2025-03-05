local M = {}

M.config = {
  win = {
    height = 0.3,
    width = 0.8,
    border = "rounded",
    row_off = -2,
    title = "Cmdpalette",
    title_pos = "center",
  },
  sign = {
    text = ":",
  },
  buf = {
    filetype = "vim",
    syntax = "vim",
  },
  delete_confirm = true,
  show_title = true,
  start_insert  = true,
}

local palette, buf, type

local function create_buf(list)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.cmd.bwipeout()
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "cmdpalette")
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", M.config.buf.filetype, { buf = buf })
  vim.api.nvim_set_option_value("syntax", M.config.buf.syntax, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })

  vim.api.nvim_buf_set_lines(buf, 1, -1, false, list)
end

local function create_win()
  local width = vim.api.nvim_get_option_value("columns", {})
  local height = vim.api.nvim_get_option_value("lines", {})

  local win_height = math.ceil(height * M.config.win.height)
  local win_width = math.ceil(width * M.config.win.width)
  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row + M.config.win.row_off,
    col = col,
    border = M.config.win.border,
  }
  palette = vim.api.nvim_open_win(buf, true, opts)

  if vim.fn.has "nvim-0.9" == 1 and M.config.show_title then
    vim.api.nvim_win_set_config(palette, {
      title = M.config.win.title,
      title_pos = M.config.win.title_pos,
    })
  end

  vim.api.nvim_set_option_value("cursorline", true, { scope = "local", win = palette })
end

function M.execute_cmd()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_win_close(0, false)
  local ok, err = pcall(vim.cmd, line) ---@diagnostic disable-line: param-type-mismatch
  if not ok then
    vim.api.nvim_notify(err, vim.log.levels.ERROR, {}) ---@diagnostic disable-line: param-type-mismatch
  end
  vim.fn.histadd(type, line)
end

function M.clear_history()
  if vim.fn.line "." == 1 then
    return
  end
  vim.cmd "redraw"
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local msg = string.format("Are you sure you want to delete [%s] from a cmdline-history?", line)
  if M.config.delete_confirm and vim.fn.confirm(msg, "&Yes\n&No") ~= 1 then
    return
  end
  local pattern = string.format([[^%s$]], vim.fn.escape(line, "^$.*/\\[]~"))
  if vim.fn.histdel(type, pattern) then
    vim.cmd "wshada!"
    M.redraw()
    vim.api.nvim_win_set_cursor(0, { row - 1, col })
    if not M.config.delete_confirm then
      vim.api.nvim_notify(string.format('[cmdpalette]: "%s" has been deleted', line), vim.log.levels.WARN, {})
    end
  end
end

local function buf_keymap()
  local opts = { nowait = true, noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>quit<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>quit<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-d>", "<Cmd>lua require'cmdpalette'.clear_history()<CR>", opts)
  if type == "cmd" then
    vim.api.nvim_buf_set_keymap(buf, "i", "<CR>", "<Esc><Cmd>lua require'cmdpalette'.execute_cmd()<CR>", opts)
  end
end

local function set_sign(len)
  vim.opt_local.signcolumn = "yes"
  vim.fn.sign_define("CmdPaletteSign", { text = M.config.sign.text, texthl = "CmdPaletteSign" })
  for i = 1, len do
    vim.fn.sign_place(0, "", "CmdPaletteSign", buf, { lnum = i })
  end
end

function M.redraw()
  local n = vim.fn.histnr(type)
  local cmd_list = {}
  for i = 1, n do
    cmd_list[i] = vim.fn.histget(type, i)
  end
  cmd_list = vim.fn.reverse(cmd_list)

  create_buf(cmd_list)
  create_win()
  buf_keymap()
  set_sign(#cmd_list)

  vim.opt_local.number = false
end

function M.open()
  type = "cmd"
  M.redraw()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  if M.config.start_insert then
    vim.cmd "startinsert"
  end
end

function M.setup(conf)
  M.config = vim.tbl_deep_extend("force", M.config, conf or {})

  vim.api.nvim_set_hl(0, "CmdpaletteSign", { default = true, link = "NonText" })

  local cmdpalette = vim.api.nvim_create_augroup("cmdpalette", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = cmdpalette,
    pattern = "cmdpalette",
    callback = function()
      local old_undolevels = vim.api.nvim_get_option_value("undolevels", { buf = 0 })
      vim.api.nvim_set_option_value("undolevels", -1, { buf = 0 })
      vim.cmd [[silent keeppatterns g/^qa\?!\?$/d_]]
      vim.cmd [[silent keeppatterns g/^wq\?a\?!\?$/d_]]
      if vim.fn.line "$" > 1 then
        vim.cmd [[silent keeppatterns 2,$g/^$/d_]]
      end
      vim.api.nvim_set_option_value("undolevels", old_undolevels, { buf = 0 })
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = cmdpalette,
    pattern = "cmdpalette",
    callback = function()
      vim.api.nvim_win_close(palette, false)
    end,
  })
end

return M
