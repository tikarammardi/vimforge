-- Solution replay: for every registered lesson, drive the real engine and
-- feed each exercise's canonical solution via feedkeys, asserting the
-- validator passes. This proves each lesson's expected end-states against
-- actual Neovim semantics (operators, text objects, motions, ...).
local state = require("vimforge.state")
local config = require("vimforge.config")
local progress = require("vimforge.progress")
local registry = require("vimforge.lessons")
local runner = require("vimforge.runner")

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function wait_for(pred, timeout)
  return vim.wait(timeout or 3000, pred)
end

describe("solutions replay", function()
  before_each(function()
    config.reset()
    local tmp = vim.fn.tempname() .. "-vimforge-sol"
    vim.fn.mkdir(tmp, "p")
    config.setup({ data_dir = tmp, persist_progress = true, check_delay = 20 })
    progress.reset_all()
    state.reset_all()
    vim.cmd("enew!")
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

  it("every exercise's canonical solution passes its validator", function()
    local all = registry.all()
    assert.is_true(#all > 0, "no lessons registered")
    for _, lesson in ipairs(all) do
      runner.start(lesson.id)
      assert.are.equal("active", state.active.status,
        string.format("%s: runner did not start", lesson.id))
      for i, ex in ipairs(lesson.exercises) do
        assert.are.equal(ex.id, state.active.exercise and state.active.exercise.id,
          string.format("%s: expected active exercise %s, got %s",
            lesson.id, ex.id, state.active.exercise and state.active.exercise.id or "nil"))
        feed(ex.solution.keys)
        assert.is_true(wait_for(function()
          return state.active.status == "success"
        end), string.format("%s/%s: solution did not pass validation", lesson.id, ex.id))
        if i < #lesson.exercises then
          feed("\r")
          assert.is_true(wait_for(function()
            return state.active.status == "active"
          end, 2000), string.format("%s: did not advance past %s", lesson.id, ex.id))
        end
      end
      -- Complete the lesson.
      feed("\r")
      assert.is_true(wait_for(function()
        return state.active.status == "idle"
      end, 2000), string.format("%s: lesson did not complete", lesson.id))
    end
  end)
end)
