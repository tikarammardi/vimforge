local M = {}

M.defaults = {
  -- milliseconds of quiet after an event before a validation check runs
  check_delay = 120,
  -- width (columns) of the instruction panel split
  panel_width = 34,
  -- persist progress to disk
  persist_progress = true,
  -- open the lesson selector automatically on VimEnter
  auto_start = false,
  -- directory for progress.json and temp exercise files; defaults to
  -- stdpath("data") .. "/vimforge"
  data_dir = nil,
}

M.config = vim.deepcopy(M.defaults)
M.initialized = false

function M.setup(opts)
  if M.initialized then
    vim.notify("vimforge: setup() called more than once", vim.log.levels.WARN)
    return
  end
  M.initialized = true
  M.config = vim.tbl_extend("force", vim.deepcopy(M.defaults), opts or {})
  if not M.config.data_dir then
    M.config.data_dir = vim.fn.stdpath("data") .. "/vimforge"
  end
  if M.config.auto_start then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        require("vimforge").open()
      end,
    })
  end
end

-- Returns the active config, configuring with defaults if setup() was never
-- called. Lets :VimForge* work out of the box.
function M.ensure()
  if not M.initialized then
    M.setup({})
  end
  return M.config
end

-- Test hook: discard any configuration so a test can start clean.
function M.reset()
  M.initialized = false
  M.config = vim.deepcopy(M.defaults)
end

return M
