local validator = require("vimforge.validator")

local function ctx(overrides)
  local c = {
    lines = { "hello world" },
    cursor = { 1, 0 },
    cursor_in_scratch = true,
    mode = "n",
    selection = nil,
    command_history = {},
    keys = {},
    file_lines = nil,
    initial_lines = { "hello world" },
  }
  for k, v in pairs(overrides or {}) do
    c[k] = v
  end
  return c
end

describe("buffer validator", function()
  it("matches identical content", function()
    assert.is_true(validator.check({ type = "buffer", expected = { "hello world" } },
      ctx()))
  end)

  it("ignores trailing whitespace per line", function()
    assert.is_true(validator.check({ type = "buffer", expected = { "hello world" } },
      ctx({ lines = { "hello world   " } })))
  end)

  it("ignores trailing blank lines", function()
    assert.is_true(validator.check({ type = "buffer", expected = { "a", "b" } },
      ctx({ lines = { "a", "b", "", "" } })))
  end)

  it("fails on different content", function()
    assert.is_false(validator.check({ type = "buffer", expected = { "hello world" } },
      ctx({ lines = { "goodbye world" } })))
  end)

  it("fails when a middle line is blank but expected is not", function()
    assert.is_false(validator.check({ type = "buffer", expected = { "a", "b" } },
      ctx({ lines = { "a", "", "b" } })))
  end)
end)

describe("cursor_position validator", function()
  it("matches the exact cell", function()
    assert.is_true(validator.check(
      { type = "cursor_position", position = { 2, 3 } },
      ctx({ cursor = { 2, 3 } })))
  end)

  it("fails on a different cell", function()
    assert.is_false(validator.check(
      { type = "cursor_position", position = { 2, 3 } },
      ctx({ cursor = { 2, 4 } })))
  end)

  it("fails when the cursor is not in the scratch buffer", function()
    assert.is_false(validator.check(
      { type = "cursor_position", position = { 1, 0 } },
      ctx({ cursor = { 1, 0 }, cursor_in_scratch = false })))
  end)
end)

describe("mode validator", function()
  it("matches by friendly name", function()
    assert.is_true(validator.check({ type = "mode", expected = "normal" },
      ctx({ mode = "n" })))
    assert.is_true(validator.check({ type = "mode", expected = "insert" },
      ctx({ mode = "i" })))
  end)

  it("maps term-code insert (ic) to insert", function()
    assert.is_true(validator.check({ type = "mode", expected = "insert" },
      ctx({ mode = "ic" })))
  end)

  it("matches any name in a list", function()
    assert.is_true(validator.check(
      { type = "mode", expected = { "normal", "insert" } },
      ctx({ mode = "i" })))
    assert.is_false(validator.check(
      { type = "mode", expected = { "normal", "insert" } },
      ctx({ mode = "v" })))
  end)

  it("fails when mode is unknown (not in scratch buffer)", function()
    local c = ctx()
    c.mode = nil
    assert.is_false(validator.check({ type = "mode", expected = "normal" }, c))
  end)
end)

describe("selection validator", function()
  it("matches an exact selection", function()
    assert.is_true(validator.check(
      { type = "selection", start = { 1, 0 }, finish = { 1, 5 } },
      ctx({ selection = { start = { 1, 0 }, finish = { 1, 5 } } })))
  end)

  it("accepts a selection extending over trailing whitespace", function()
    assert.is_true(validator.check(
      { type = "selection", start = { 1, 0 }, finish = { 1, 5 } },
      ctx({
        lines = { "apple banana" },
        selection = { start = { 1, 0 }, finish = { 1, 6 } },
      })))
  end)

  it("rejects a selection extending over non-whitespace", function()
    assert.is_false(validator.check(
      { type = "selection", start = { 1, 0 }, finish = { 1, 5 } },
      ctx({
        lines = { "apple banana" },
        selection = { start = { 1, 0 }, finish = { 1, 7 } },
      })))
  end)

  it("fails with no selection", function()
    assert.is_false(validator.check(
      { type = "selection", start = { 1, 0 }, finish = { 1, 5 } },
      ctx({})))
  end)
end)

describe("register validator", function()
  it("matches the unnamed register", function()
    vim.fn.setreg("\"", "yanked-word")
    assert.is_true(validator.check(
      { type = "register", expected = "yanked-word" }, ctx()))
  end)

  it("trims surrounding whitespace by default", function()
    vim.fn.setreg("\"", "  padded  ")
    assert.is_true(validator.check(
      { type = "register", expected = "padded" }, ctx()))
  end)

  it("compares raw register contents without trimming", function()
    vim.fn.setreg("\"", "  padded  ")
    assert.is_false(validator.check(
      { type = "register", expected = "padded", trim = false }, ctx()))
  end)
end)

describe("search validator", function()
  it("matches the last search pattern", function()
    vim.fn.setreg("/", "needle")
    assert.is_true(validator.check({ type = "search", pattern = "needle" }, ctx()))
    assert.is_false(validator.check({ type = "search", pattern = "other" }, ctx()))
  end)
end)

describe("command validator", function()
  it("requires every expected group to appear", function()
    assert.is_true(validator.check(
      { type = "command", expected = { "w" } },
      ctx({ command_history = { "w" } })))
    assert.is_false(validator.check(
      { type = "command", expected = { "w", "q" } },
      ctx({ command_history = { "w" } })))
  end)

  it("accepts alias spellings", function()
    assert.is_true(validator.check(
      { type = "command", expected = { "w" } },
      ctx({ command_history = { "write" } })))
    assert.is_true(validator.check(
      { type = "command", expected = { "q" } },
      ctx({ command_history = { "q!" } })))
    assert.is_true(validator.check(
      { type = "command", expected = { "help" } },
      ctx({ command_history = { "h" } })))
  end)
end)

describe("file validator", function()
  it("matches temp file contents", function()
    assert.is_true(validator.check(
      { type = "file", expected = { "saved line" } },
      ctx({ file_lines = { "saved line  " } })))
  end)

  it("fails when no file is present", function()
    assert.is_false(validator.check(
      { type = "file", expected = { "x" } }, ctx({})))
  end)
end)

describe("sequence validator", function()
  it("detects an exact recorded sequence", function()
    assert.is_true(validator.check(
      { type = "sequence", allowed = { { "d", "w" } } },
      ctx({ keys = { "d", "w" } })))
  end)

  it("detects an ordered subsequence with other keys around it", function()
    assert.is_true(validator.check(
      { type = "sequence", allowed = { { "d", "w" } } },
      ctx({ keys = { "h", "d", "l", "w", "j" } })))
  end)

  it("fails when the order is wrong", function()
    assert.is_false(validator.check(
      { type = "sequence", allowed = { { "d", "w" } } },
      ctx({ keys = { "w", "d" } })))
  end)

  it("accepts any of several allowed sequences", function()
    assert.is_true(validator.check(
      { type = "sequence", allowed = { { "d", "w" }, { "c", "w" } } },
      ctx({ keys = { "c", "w" } })))
  end)
end)

describe("composite validator", function()
  it("passes only when every sub-validation passes", function()
    local v = {
      type = "composite",
      validations = {
        { type = "buffer", expected = { "hello world" } },
        { type = "cursor_position", position = { 1, 0 } },
      },
    }
    assert.is_true(validator.check(v, ctx()))
    assert.is_false(validator.check(v, ctx({ cursor = { 1, 5 } })))
  end)

  it("combines mode and buffer", function()
    local v = {
      type = "composite",
      validations = {
        { type = "buffer", expected = { "done" } },
        { type = "mode", expected = "normal" },
      },
    }
    assert.is_true(validator.check(v, ctx({ lines = { "done" } })))
    assert.is_false(validator.check(v, ctx({ lines = { "done" }, mode = "i" })))
  end)
end)

describe("check() dispatch", function()
  it("errors on an unknown validator type", function()
    assert.has_error(function()
      validator.check({ type = "does-not-exist" }, ctx())
    end)
  end)
end)
