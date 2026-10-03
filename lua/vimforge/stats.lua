-- Stats: lesson completion + practice numbers, rendered as a float.
local M = {}

function M.rows()
  local lessons = require("vimforge.lessons")
  local progress = require("vimforge.progress")
  local practice = require("vimforge.practice")
  local data = progress.load()

  local rows = { { text = "  V I M F O R G E   stats", hl = "VimForgeTitle" } }

  local done_lessons = 0
  for _, l in ipairs(lessons.all()) do
    local ex_total = #l.exercises
    local ex_done = 0
    local ld = data.lessons[l.id]
    for _, ex in ipairs(l.exercises) do
      local e = ld and ld.exercises and ld.exercises[ex.id]
      if e and e.completed then
        ex_done = ex_done + 1
      end
    end
    local complete = (ex_done == ex_total)
    if complete then
      done_lessons = done_lessons + 1
    end
    rows[#rows + 1] = {
      text = string.format("  [%s] %-24s %d/%d", complete and "x" or " ", l.title, ex_done, ex_total),
      hl = complete and "VimForgeSuccess" or "VimForgeInstruction",
    }
  end
  rows[#rows + 1] = {
    text = string.format("  Lessons: %d/%d complete   overall %d%%",
      done_lessons, #lessons.all(), progress.percent()),
    hl = "VimForgeProgress",
  }
  rows[#rows + 1] = { text = "" }

  rows[#rows + 1] = { text = "  Practice", hl = "VimForgeTitle" }
  local stats = progress.practice_stats()
  local total = 0
  for _, cat in ipairs(practice.category_names()) do
    local c = stats[cat]
    if c and c.completed > 0 then
      total = total + c.completed
      rows[#rows + 1] = {
        text = string.format("  %-14s %3d done   avg %.1fs   best %.1fs",
          cat, c.completed, (c.total_ms / c.completed) / 1000, (c.best_ms or 0) / 1000),
        hl = "VimForgeInstruction",
      }
    end
  end
  if total == 0 then
    rows[#rows + 1] = { text = "  (no practice yet)", hl = "VimForgeDim" }
  else
    rows[#rows + 1] = { text = string.format("  Total: %d tasks", total), hl = "VimForgeProgress" }
  end
  rows[#rows + 1] = { text = "  <CR> or q to close", hl = "VimForgeDim" }
  return rows
end

function M.show()
  local ui = require("vimforge.ui")
  ui.setup_highlights()
  local rows = M.rows()
  local win, buf = ui.show_selector(rows)
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<CR>", close, { buffer = buf })
  return win, buf
end

return M
