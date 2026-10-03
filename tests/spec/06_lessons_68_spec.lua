-- Lessons 6-8 (visual mode, searching, ex commands) behavior:
-- valid alternative solutions must pass, clearly wrong actions must not,
-- and F1 hints must work while the learner is in VISUAL mode.
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

local function wait_success(msg)
  assert.is_true(wait_for(function()
    return state.active.status == "success"
  end), msg or "did not reach success")
end

-- Let the debounced check settle, then assert the exercise has NOT passed.
local function expect_still_active(msg)
  vim.wait(500, function()
    return state.active.status == "success"
  end)
  assert.are.equal("active", state.active.status, msg)
end

local function exercise(lesson_id, ex_id)
  local lesson = registry.get(lesson_id)
  for _, ex in ipairs(lesson.exercises) do
    if ex.id == ex_id then
      return ex
    end
  end
  error("unknown exercise " .. lesson_id .. "/" .. ex_id)
end

describe("lessons 6-8 behavior", function()
  before_each(function()
    config.reset()
    local tmp = vim.fn.tempname() .. "-vimforge-beh"
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

  -- Starts the lesson and jumps straight to the given exercise.
  local function begin_at(lesson_id, ex_id)
    runner.start(lesson_id)
    assert.are.equal("active", state.active.status)
    local ex = exercise(lesson_id, ex_id)
    if state.active.exercise.id ~= ex_id then
      runner.start_exercise(ex)
    end
    assert.are.equal(ex_id, state.active.exercise.id)
  end

  describe("valid alternatives", function()
    it("visual: manual selection vlllU uppercases 'this'", function()
      begin_at("visual-mode", "uppercase-a-selection")
      feed("vlllU")
      wait_success("vlllU should uppercase 'this'")
    end)

    it("visual: blockwise <C-v>jl covers the same rectangle as <C-v>lj", function()
      begin_at("visual-mode", "blockwise-select-columns")
      feed("<C-v>jl")
      wait_success("<C-v>jl should cover the same rectangle")
    end)

    it("ex-commands: :write (long form) passes the :w exercise", function()
      begin_at("ex-commands", "save-file-with-:w")
      feed("A 1.0<Esc>:write\r")
      wait_success(":write should pass the :w exercise")
    end)

    it("ex-commands: :quit (long form) passes the :q exercise", function()
      begin_at("ex-commands", "close-buffer-with-:q")
      feed(":quit\r")
      wait_success(":quit should pass the :q exercise")
    end)

    it("ex-commands: :%s range form passes the :s exercise", function()
      begin_at("ex-commands", "substitute-with-:s")
      feed(":%s/cat/dog/\r")
      wait_success(":%s/cat/dog/ should pass (range prefix must be stripped)")
    end)
  end)

  describe("negative: wrong actions must not pass", function()
    it("visual: overshooting selection vll does not pass", function()
      begin_at("visual-mode", "select-chars-with-v")
      feed("vll")
      expect_still_active("vll selects 'hel', expected 'he'")
    end)

    it("visual: Vjd selects two lines and deletes one too many", function()
      begin_at("visual-mode", "delete-a-line-visually")
      feed("Vjd")
      expect_still_active("Vjd deletes lines 2-3, leaving only 'first'")
    end)

    it("searching: N after /cat lands on the wrong match", function()
      begin_at("searching", "next-match-with-n")
      feed("/cat\rN")
      expect_still_active("N wraps to the last match, expected the second")
    end)

    it("searching: ?and does not match the required pattern", function()
      begin_at("searching", "search-backward-with-question")
      feed("?and\r")
      expect_still_active("pattern 'and' != 'cat'")
    end)

    it("ex-commands: :w without editing does not pass the file check", function()
      begin_at("ex-commands", "save-file-with-:w")
      feed(":w\r")
      expect_still_active("file still reads 'release'")
    end)

    it("ex-commands: reversed substitution does not change the buffer", function()
      begin_at("ex-commands", "substitute-with-:s")
      feed(":s/dog/cat/\r")
      expect_still_active("buffer still reads 'the cat sat'")
    end)
  end)

  describe("hints", function()
    it("F1 shows a hint in normal mode", function()
      begin_at("searching", "search-forward-with-slash")
      feed("<F1>")
      assert.is_true(wait_for(function()
        return state.active.hints_shown == 1
      end), "F1 in normal mode should show a hint")
    end)

    it("F1 shows a hint while in VISUAL mode", function()
      begin_at("visual-mode", "select-chars-with-v")
      feed("v")
      assert.is_true(wait_for(function()
        return vim.api.nvim_get_mode().mode == "v"
      end), "did not enter visual mode")
      feed("<F1>")
      assert.is_true(wait_for(function()
        return state.active.hints_shown == 1
      end), "F1 in visual mode should show a hint")
    end)
  end)
end)
