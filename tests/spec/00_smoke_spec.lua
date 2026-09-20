-- Verifies the plenary harness can load the plugin in a clean nvim.
describe("harness smoke", function()
  it("runs inside a clean Neovim", function()
    assert.is_true(vim.g.loaded_vimforge == nil or vim.g.loaded_vimforge == 1)
    assert.is_number(vim.fn.has("nvim-0.11") == 1 and 1 or 0)
  end)

  it("loads the vimforge module tree", function()
    for _, name in ipairs({
      "vimforge",
      "vimforge.config",
      "vimforge.state",
      "vimforge.lesson",
      "vimforge.lessons",
      "vimforge.validator",
      "vimforge.progress",
    }) do
      local ok, mod = pcall(require, name)
      assert.is_true(ok, "failed to load " .. name .. ": " .. tostring(mod))
    end
  end)

  it("configures with defaults when setup() is not called", function()
    local config = require("vimforge.config")
    config.reset()
    local cfg = config.ensure()
    assert.are.equal(120, cfg.check_delay)
    assert.is_not_nil(cfg.data_dir)
    assert.is_false(cfg.auto_start)
    config.reset()
  end)
end)
