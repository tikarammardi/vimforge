-- Minimal Neovim config for the vimforge test suite. Runs with --noplugin so
-- the user's real configuration never interferes. Puts the repo root and
-- plenary.nvim on the runtimepath.
local root = vim.env.VIMFORGE_ROOT
if not root then
  -- Fallback: this file lives in <root>/tests/
  local src = debug.getinfo(2).source or ""
  root = vim.fn.fnamemodify(src:sub(2), ":p:h") .. "/.."
end
vim.opt.rtp:prepend(vim.fn.simplify(root))

local plenary = vim.env.VIMFORGE_PLENARY
if not plenary then
  for _, p in ipairs({
    vim.fn.stdpath("data") .. "/nvim/lazy/plenary.nvim",
    vim.fn.stdpath("data") .. "/nim/lazy/plenary.nvim",
  }) do
    if vim.fn.isdirectory(p) == 1 then
      plenary = p
      break
    end
  end
end
if plenary then
  vim.opt.rtp:append(plenary)
end
