local M = {}

M.config = {
  win = {
    height = 0.3,
    width = 0.8,
    max_width = 120,
    border = "rounded",
    row_off = -2,
    title = " Cmdpalette ",
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
  start_insert = true,
}

M.state = {
  win = nil,
  buf = nil,
  type = "cmd",
}

local function get_history_list(type)
  local n = vim.fn.histnr(type)
  local cmd_list = {}
  local ignore_patterns = {
    "^qa?%!?$",
    "^wq?a?%!?$",
    "^$",
  }

  for i = 1, n do
    local h = vim.fn.histget(type, i)
    local should_ignore = false

    for _, pattern in ipairs(ignore_patterns) do
      if h:match(pattern) then
        should_ignore = true
        break
      end
    end

    if h ~= "" and not should_ignore then
      table.insert(cmd_list, 1, h) -- insert in reverse order
    end
  end

  return cmd_list
end

local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "cmdpalette")
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", M.config.buf.filetype, { buf = buf })
  vim.api.nvim_set_option_value("syntax", M.config.buf.syntax, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  return buf
end

local function create_win(buf)
  local screen_height = vim.api.nvim_get_option_value("lines", {})
  local float_height = math.floor(screen_height * M.config.win.height)
  local row = math.floor((screen_height - float_height) / 2)

  local screen_width = vim.api.nvim_get_option_value("columns", {})
  local float_width = math.floor(screen_width * M.config.win.width)
  if M.config.win.max_width and M.config.win.max_width > 0 then
    float_width = math.min(float_width, M.config.win.max_width)
  end
  if float_width > screen_width - 4 then
    float_width = screen_width - 4
  end
  local col = math.floor((screen_width - float_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = float_width,
    height = float_height,
    row = row + M.config.win.row_off,
    col = col,
    border = M.config.win.border,
  }
  local win = vim.api.nvim_open_win(buf, true, opts)
  if M.config.show_title then
    vim.api.nvim_win_set_config(win, {
      title = M.config.win.title,
      title_pos = M.config.win.title_pos,
    })
  end
  vim.api.nvim_set_option_value("cursorline", true, { scope = "local", win = win })

  return win
end

function M.execute_cmd()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_win_close(0, false)
  local ok, err = pcall(vim.cmd, line) ---@diagnostic disable-line: param-type-mismatch
  if not ok then
    vim.api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
  end
  vim.fn.histadd(M.state.type, line)
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
  if vim.fn.histdel(M.state.type, pattern) then
    vim.cmd "wshada!"
    M.refresh(M.state)
    vim.api.nvim_win_set_cursor(0, { row - 1, col })
    if not M.config.delete_confirm then
      vim.api.nvim_echo({ { string.format('[cmdpalette]: "%s" has been deleted', line), "WarningMsg" } }, true, {})
    end
  end
end

local function apply_keymaps(buf, type)
  local opts = { buffer = buf, nowait = true, noremap = true, silent = true }
  vim.keymap.set("n", "q", "<Cmd>quit<CR>", opts)
  vim.keymap.set("n", "<Esc>", "<Cmd>quit<CR>", opts)
  vim.keymap.set("n", "<C-d>", M.clear_history, opts)

  if type == "cmd" then
    vim.keymap.set({ "n", "i" }, "<CR>", function()
      if vim.api.nvim_get_mode().mode == "i" then
        vim.cmd "stopinsert"
      end
      -- Use schedule to safely execute after exiting insert mode
      vim.schedule(function()
        M.execute_cmd()
      end)
    end, opts)
  end
end

local function set_sign(buf, len)
  vim.opt_local.signcolumn = "yes"
  vim.fn.sign_define("CmdPaletteSign", { text = M.config.sign.text, texthl = "CmdPaletteSign" })
  for i = 1, len do
    vim.fn.sign_place(0, "", "CmdPaletteSign", buf, { lnum = i })
  end
end

function M.refresh(state)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local cmd_list = get_history_list(state.type)
  vim.api.nvim_buf_set_lines(state.buf, 1, -1, false, cmd_list)
  set_sign(state.buf, #cmd_list)
end

function M.open()
  M.state.type = "cmd"
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end

  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
    M.state.buf = create_buf()
  end

  local cmd_list = get_history_list(M.state.type)
  vim.api.nvim_buf_set_lines(M.state.buf, 1, -1, false, cmd_list)

  M.state.win = create_win(M.state.buf)
  apply_keymaps(M.state.buf, M.state.type)
  set_sign(M.state.buf, #cmd_list)
  vim.opt_local.number = false
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  if M.config.start_insert then
    vim.cmd "startinsert"
  end
end

function M.setup(conf)
  M.config = vim.tbl_deep_extend("force", M.config, conf or {})

  vim.api.nvim_set_hl(0, "CmdpaletteSign", { default = true, link = "NonText" })

  local cmdpalette = vim.api.nvim_create_augroup("cmdpalette", {})
  vim.api.nvim_create_autocmd("BufLeave", {
    group = cmdpalette,
    pattern = "cmdpalette",
    callback = function()
      vim.api.nvim_win_close(M.state.win, false)
    end,
  })
end

return M
