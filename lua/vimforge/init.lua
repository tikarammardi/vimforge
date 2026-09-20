-- vimforge.nvim — learn Vim by using real Vim.
--
-- Public API (expanded across phases; see doc/vimforge.txt):
--   require("vimforge").setup(opts)  configure (defaults work without it)
local M = {}

local config = require("vimforge.config")

function M.setup(opts)
  config.setup(opts)
end

function M.config()
  return config.ensure()
end

return M
