-- User commands. Defined at plugin load; each lazily requires the engine so
-- that simply having the plugin on the runtimepath has no startup cost.
local M = {}

local function lesson_complete()
  return function()
    local lessons = require("vimforge.lessons")
    local out = {}
    for i, l in ipairs(lessons.all()) do
      out[i] = l.id
    end
    return out
  end
end

function M.define()
  vim.api.nvim_create_user_command("VimForge", function()
    require("vimforge").open()
  end, {})

  vim.api.nvim_create_user_command("VimForgeStart", function(opts)
    local id = (opts.args or ""):match("^%s*(.-)%s*$")
    require("vimforge").start(id ~= "" and id or nil)
  end, { nargs = "?", complete = lesson_complete() })

  vim.api.nvim_create_user_command("VimForgeNext", function()
    require("vimforge").next()
  end, {})

  vim.api.nvim_create_user_command("VimForgeRestart", function()
    require("vimforge").restart()
  end, {})

  vim.api.nvim_create_user_command("VimForgeProgress", function()
    require("vimforge").show_progress()
  end, {})

  vim.api.nvim_create_user_command("VimForgeReset", function()
    require("vimforge").reset()
  end, {})
end

return M
