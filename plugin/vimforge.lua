if vim.g.loaded_vimforge then
  return
end
vim.g.loaded_vimforge = 1

require("vimforge.commands").define()
