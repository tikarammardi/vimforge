-- End-to-end: drive the real engine in a clean nvim, solving Lesson 1 with
-- feedkeys, and verify success flow, progress persistence, and that the
-- learner's own buffer is restored on exit.
local state = require("vimforge.state")
local config = require("vimforge.config")
local progress = require("vimforge.progress")
local registry = require("vimforge.lessons")
local runner = require("vimforge.runner")

local tmp

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function wait_for(pred, timeout)
  return vim.wait(timeout or 3000, pred)
end

describe("runner e2e", function()
  local user_buf

  before_each(function()
    config.reset()
    tmp = vim.fn.tempname() .. "-vimforge-e2e"
    vim.fn.mkdir(tmp, "p")
    config.setup({ data_dir = tmp, persist_progress = true, check_delay = 20 })
    progress.reset_all()
    state.reset_all()
    -- A "user" buffer that must survive the lesson.
    vim.cmd("enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "user line 1", "user line 2" })
    user_buf = vim.api.nvim_get_current_buf()
  end)

  after_each(function()
    runner._quit_cleanup()
    if state.active.selector_win and vim.api.nvim_win_is_valid(state.active.selector_win) then
      vim.api.nvim_win_close(state.active.selector_win, true)
    end
    state.reset_all()
    progress.reset_all()
    config.reset()
    vim.cmd("enew!")
  end)

  it("completes lesson 1 end to end and persists progress", function()
    runner.start("intro-to-modes")
    assert.are.equal("active", state.active.status)
    assert.are.equal("type-with-i", state.active.exercise.id)

    local lesson = registry.get("intro-to-modes")
    for i, ex in ipairs(lesson.exercises) do
      feed(ex.solution.keys)
      assert.is_true(wait_for(function()
        return state.active.status == "success"
      end), "exercise " .. ex.id .. " did not reach success")
      assert.are.equal(ex.id, state.active.exercise.id)

      if i < #lesson.exercises then
        feed("\r")
        assert.is_true(wait_for(function()
          return state.active.status == "active"
        end, 2000), "did not advance to next exercise")
        assert.are.equal(lesson.exercises[i + 1].id, state.active.exercise.id)
      end
    end

    -- Finish the lesson: <CR> after the last success -> selector, status idle.
    feed("\r")
    assert.is_true(wait_for(function()
      return state.active.status == "idle"
    end, 2000), "lesson did not complete")

    local data = progress.load()
    local l = data.lessons["intro-to-modes"]
    assert.is_true(l.completed, "lesson was not marked complete")
    assert.are.equal(#lesson.exercises, vim.fn.len(l.exercises))
  end)

  it("restores the user's buffer on quit", function()
    runner.start("intro-to-modes")
    assert.is_true(wait_for(function()
      return state.active.status == "active"
    end))
    -- Leave the lesson via the buffer-local q.
    feed("q")
    assert.is_true(wait_for(function()
      return state.active.status == "idle"
    end, 2000), "quit did not return to idle")
    -- The user buffer should be current again and intact.
    assert.are.equal(user_buf, vim.api.nvim_get_current_buf(), "user buffer not restored")
    assert.are.same({ "user line 1", "user line 2" },
      vim.api.nvim_buf_get_lines(user_buf, 0, -1, false))
  end)

  it("does not leak scratch buffers or autocmds after quit", function()
    runner.start("intro-to-modes")
    assert.is_true(wait_for(function()
      return state.active.status == "active"
    end))
    local scratch = state.active.buf
    assert.is_not_nil(scratch, "no scratch buffer was created")
    feed("q")
    assert.is_true(wait_for(function()
      return state.active.status == "idle"
    end, 2000), "quit did not return to idle")
    assert.is_false(vim.api.nvim_buf_is_valid(scratch), "scratch buffer leaked")
    local autocmds = vim.api.nvim_get_autocmds({ group = "VimForge" })
    assert.are.equal(0, #autocmds, "autocmds leaked")
  end)
end)
