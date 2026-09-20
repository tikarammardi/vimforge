-- UI: highlights, the instruction panel (right split), the lesson selector
-- (centered float), and target markers. Pure presentation — no game logic.
local M = {}

local config = require("vimforge.config")

local ns = vim.api.nvim_create_namespace("vimforge")

local HIGHLIGHTS = {
  VimForgeTitle = { fg = "#7aa2f7", bold = true },
  VimForgeInstruction = { fg = "#c0caf5" },
  VimForgeHint = { fg = "#e0af68", italic = true },
  VimForgeSuccess = { fg = "#9ece6a", bold = true },
  VimForgeError = { fg = "#f7768e", bold = true },
  VimForgeTarget = { fg = "#ff9e64", bold = true },
  VimForgeProgress = { fg = "#bb9af7" },
  VimForgeDim = { fg = "#565f89" },
  VimForgeSelected = { fg = "#7aa2f7", bold = true },
}

function M.setup_highlights()
  for name, attrs in pairs(HIGHLIGHTS) do
    if vim.fn.hlexists(name) ~= 1 then
      vim.api.nvim_set_hl(0, name, attrs)
    end
  end
end

-- rows: { { text = "...", hl = "Group" }, ... } (hl optional)
function M.render_buffer(buf, rows)
  local lines = {}
  for i, row in ipairs(rows) do
    lines[i] = row.text
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for i, row in ipairs(rows) do
    if row.hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        hl_group = row.hl,
        end_col = #row.text,
        priority = 100,
      })
    end
  end
  vim.bo[buf].modifiable = false
end

local function scratch_options(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
end

local function minimal_window(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].list = false
  vim.wo[win].wrap = true
end

-- Opens the instruction panel as a real right-hand vertical split so it never
-- covers the practice buffer. Falls back to a float on very narrow terminals.
function M.open_panel()
  M.setup_highlights()
  local buf = vim.api.nvim_create_buf(false, true)
  scratch_options(buf)
  vim.bo[buf].filetype = "vimforge"

  local cols, rows_ = vim.o.columns, vim.o.lines
  local width = math.min(config.ensure().panel_width, math.floor(cols * 0.4))
  local win
  if cols >= 64 then
    vim.cmd("vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(win, width)
    vim.api.nvim_set_current_buf(buf)
  else
    win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = math.min(30, math.floor(cols * 0.6)),
      height = math.min(10, math.floor(rows_ * 0.5)),
      col = 0,
      row = 0,
      border = "single",
      style = "minimal",
    })
  end
  minimal_window(win)
  return win, buf
end

-- Centered floating selector. Returns (win, buf).
function M.show_selector(rows)
  M.setup_highlights()
  local buf = vim.api.nvim_create_buf(false, true)
  scratch_options(buf)
  vim.bo[buf].filetype = "vimforge"

  local maxw = 1
  for _, row in ipairs(rows) do
    maxw = math.max(maxw, #row.text)
  end
  local width = math.min(maxw + 4, math.floor(vim.o.columns * 0.85))
  local height = #rows + 2
  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    style = "minimal",
  })
  minimal_window(win)
  M.render_buffer(buf, rows)
  return win, buf
end

-- Draws a target marker (▼) at the given 1-based row / 0-based col.
function M.set_target(buf, row, col)
  return vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
    hl_group = "VimForgeTarget",
    virt_text = { { "▼", "VimForgeTarget" } },
    virt_text_pos = "inline",
    priority = 50,
  })
end

-- Word-wraps text to the given width. Returns a list of lines.
function M.wrap(text, width)
  width = math.max(8, width or 40)
  local words = {}
  for w in tostring(text):gmatch("%S+") do
    words[#words + 1] = w
  end
  local lines, cur = {}, ""
  for _, w in ipairs(words) do
    if cur == "" then
      cur = w
    elseif #cur + 1 + #w <= width then
      cur = cur .. " " .. w
    else
      lines[#lines + 1] = cur
      cur = w
    end
  end
  if cur ~= "" then
    lines[#lines + 1] = cur
  end
  if #lines == 0 then
    lines[1] = ""
  end
  return lines
end

return M
