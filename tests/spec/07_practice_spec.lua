-- Practice mode: pool integrity, per-task solution replay, session flows
-- (goal / endless / time), and stats recording + rendering.
local state = require("vimforge.state")
local config = require("vimforge.config")
local progress = require("vimforge.progress")
local runner = require("vimforge.runner")
local practice = require("vimforge.practice")
local stats = require("vimforge.stats")

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

local function wait_idle(msg)
  assert.is_true(wait_for(function()
    return state.active.status == "idle"
  end, 4000), msg or "did not return to idle")
end

local POOL_LESSON = { id = "test-pool", title = "Test Pool", concept = "", exercises = {} }

describe("practice", function()
  before_each(function()
    config.reset()
    local tmp = vim.fn.tempname() .. "-vimforge-prac"
    vim.fn.mkdir(tmp, "p")
    config.setup({ data_dir = tmp, persist_progress = true, check_delay = 20 })
    progress.reset_all()
    state.reset_all()
    practice._pick = nil
    vim.cmd("enew!")
  end)

  after_each(function()
    practice._pick = nil
    runner._quit_cleanup()
    if state.active.selector_win and vim.api.nvim_win_is_valid(state.active.selector_win) then
      vim.api.nvim_win_close(state.active.selector_win, true)
    end
    state.reset_all()
    progress.reset_all()
    config.reset()
    vim.cmd("enew!")
  end)

  it("pool: every task's canonical solution passes its validator", function()
    runner._begin_session(POOL_LESSON)
    local n = 0
    for _, category in ipairs(practice.CATEGORIES) do
      for _, task in ipairs(practice.all_tasks(category)) do
        n = n + 1
        runner.start_exercise(task)
        assert.are.equal(task.id, state.active.exercise.id)
        assert.are.equal("active", state.active.status)
        feed(task.solution.keys)
        wait_success(string.format("task %s/%s: solution did not pass", category, task.id))
      end
    end
    assert.is_true(n >= 40, "expected at least 40 practice tasks, got " .. n)
  end)

  it("goal mode: auto-advances without <CR>, records stats, ends at the goal", function()
    local tasks = practice.all_tasks("movement")
    local a, b = tasks[1], tasks[2]
    local calls = 0
    practice._pick = function()
      calls = calls + 1
      return (calls == 1) and a or b
    end

    practice.start({ category = "movement", mode = "goal", goal = 2 })
    assert.is_true(wait_for(function()
      return state.active.status == "active"
    end), "practice did not start")
    assert.are.equal(a.id, state.active.exercise.id)

    feed(a.solution.keys)
    wait_success("task A did not succeed")
    -- No <CR>: the session must advance on its own.
    assert.is_true(wait_for(function()
      return state.active.exercise.id == b.id
    end, 3000), "did not auto-advance to task B")
    assert.are.equal("active", state.active.status)

    feed(b.solution.keys)
    wait_success("task B did not succeed")
    wait_idle("goal session did not end")
    assert.is_nil(state.active.practice, "practice state was not cleared")

    local c = progress.practice_stats().movement
    assert.is_not_nil(c, "no practice stats recorded")
    assert.are.equal(2, c.completed)
    assert.is_true(c.total_ms > 0, "no time recorded")
    assert.is_true(c.best_ms > 0 and c.best_ms <= c.total_ms / 2, "best_ms wrong")
  end)

  it("endless mode: keeps running until the learner quits with q", function()
    local tasks = practice.all_tasks("insertion")
    local i = 0
    practice._pick = function()
      i = i + 1
      return tasks[((i - 1) % #tasks) + 1]
    end

    practice.start({ category = "insertion", mode = "endless" })
    assert.is_true(wait_for(function()
      return state.active.status == "active"
    end), "practice did not start")

    for k = 1, 2 do
      local task = tasks[k]
      assert.is_true(wait_for(function()
        return state.active.exercise.id == task.id
      end, 3000), "did not reach task " .. k)
      feed(task.solution.keys)
      wait_success("task " .. k .. " did not succeed")
    end

    feed("q")
    wait_idle("quit did not end the endless session")
    assert.is_nil(state.active.practice)
    assert.are.equal(2, progress.practice_stats().insertion.completed)
  end)

  it("time mode: ends when the limit expires", function()
    practice.start({ category = "movement", mode = "time", limit_ms = 400 })
    assert.is_true(wait_for(function()
      return state.active.status == "active"
    end), "practice did not start")
    -- Do nothing: the 400ms timer must end the session.
    wait_idle("time mode did not end on expiry")
    assert.is_nil(state.active.practice)
  end)

  it("record_practice accumulates completed/total/best", function()
    progress.record_practice("movement", 500)
    progress.record_practice("movement", 300)
    local c = progress.practice_stats().movement
    assert.are.equal(2, c.completed)
    assert.are.equal(800, c.total_ms)
    assert.are.equal(300, c.best_ms)
  end)

  it("stats rows list lessons and practice numbers", function()
    progress.record_practice("movement", 400)
    local text = table.concat(
      vim.tbl_map(function(r)
        return r.text
      end, stats.rows()),
      "\n")
    assert.is_true(text:find("stats", 1, true) ~= nil, "stats header missing")
    assert.is_true(text:find("movement", 1, true) ~= nil, "practice category missing")
    assert.is_true(text:find("Lessons:", 1, true) ~= nil, "lesson summary missing")
  end)

  it("stats float opens and closes", function()
    local win = stats.show()
    assert.is_true(vim.api.nvim_win_is_valid(win), "stats float did not open")
    feed("q")
    assert.is_true(wait_for(function()
      return not vim.api.nvim_win_is_valid(win)
    end, 2000), "stats float did not close")
  end)
end)
