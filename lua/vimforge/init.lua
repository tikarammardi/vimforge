-- vimforge.nvim — learn Vim by using real Vim.
--
-- Public API:
--   require("vimforge").setup(opts)   configure (defaults work without it)
--   require("vimforge").open()        open the lesson selector
--   require("vimforge").start(id?)    start a lesson (default: first not done)
--   require("vimforge").next()        advance to the next exercise
--   require("vimforge").restart()     restart the current exercise
--   require("vimforge").quit()        leave the lesson, restore the window
--   require("vimforge").show_progress()  show a progress summary
--   require("vimforge").reset()       clear all saved progress
local M = {}

local config = require("vimforge.config")

function M.setup(opts)
  config.setup(opts)
end

function M.config()
  return config.ensure()
end

function M.open()
  require("vimforge.runner").selector()
end

-- Start a lesson by id, or the first lesson that is not yet complete.
function M.start(lesson_id)
  local runner = require("vimforge.runner")
  local lessons = require("vimforge.lessons")
  local progress = require("vimforge.progress")
  if not lesson_id then
    for _, l in ipairs(lessons.all()) do
      if not progress.is_lesson_complete(l.id, l) then
        lesson_id = l.id
        break
      end
    end
    lesson_id = lesson_id or (lessons.all()[1] and lessons.all()[1].id)
  end
  runner.start(lesson_id)
end

function M.next()
  require("vimforge.runner").next()
end

function M.restart()
  require("vimforge.runner").restart()
end

function M.quit()
  require("vimforge.runner").quit()
end

-- Start a practice session. opts: { category, mode, goal, limit_ms } or
-- nil for the chooser float.
function M.practice(opts)
  local practice = require("vimforge.practice")
  if opts then
    practice.start(opts)
  else
    practice.choose()
  end
end

function M.stats()
  require("vimforge.stats").show()
end

function M.show_progress()
  local lessons = require("vimforge.lessons")
  local progress = require("vimforge.progress")
  local lines = { "VimForge progress" }
  for i, l in ipairs(lessons.all()) do
    local done = progress.is_lesson_complete(l.id, l)
    lines[#lines + 1] = string.format("  [%s] %d. %s", done and "x" or " ", i, l.title)
  end
  lines[#lines + 1] = string.format("  Overall: %d%%", progress.percent())
  vim.api.nvim_notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "VimForge" })
end

function M.reset()
  local progress = require("vimforge.progress")
  progress.reset_all()
  vim.notify("vimforge: progress cleared", vim.log.levels.INFO)
end

return M
