local progress = require("vimforge.progress")
local registry = require("vimforge.lessons")
local config = require("vimforge.config")

local function two_ex_lesson()
  return registry.add({
    id = "p-lesson",
    title = "P",
    exercises = {
      { id = "e1", instruction = "a", validation = { type = "buffer", expected = {} } },
      { id = "e2", instruction = "b", validation = { type = "buffer", expected = {} } },
    },
  })
end

describe("progress persistence", function()
  local tmp

  before_each(function()
    config.reset()
    config.setup({ persist_progress = true })
    tmp = vim.fn.tempname() .. "-vimforge-progress"
    progress.set_test_path(tmp)
    progress.reset_all()
    registry.reset()
  end)

  after_each(function()
    progress.reset_all()
    progress.set_test_path(nil)
    config.reset()
  end)

  it("round-trips save/load", function()
    progress.save({ lessons = { x = { completed = true } } })
    local data = progress.load()
    assert.is_true(data.lessons.x.completed)
  end)

  it("returns an empty structure when no file exists", function()
    progress.reset_all()
    local data = progress.load()
    assert.are.same({}, data.lessons)
  end)

  it("records an exercise and persists it", function()
    progress.record_exercise("p-lesson", "e1", { attempts = 2, hints = 1 })
    local data = progress.load()
    local e = data.lessons["p-lesson"].exercises.e1
    assert.is_true(e.completed)
    assert.are.equal(2, e.attempts)
    assert.are.equal(1, e.hints)
    assert.is_number(e.completed_at)
  end)

  it("marks a lesson complete", function()
    progress.mark_lesson_complete("p-lesson")
    local data = progress.load()
    assert.is_true(data.lessons["p-lesson"].completed)
  end)

  it("detects lesson completion from its exercises", function()
    local lesson = two_ex_lesson()
    assert.is_false(progress.is_lesson_complete("p-lesson", lesson))
    progress.record_exercise("p-lesson", "e1")
    assert.is_false(progress.is_lesson_complete("p-lesson", lesson))
    progress.record_exercise("p-lesson", "e2")
    assert.is_true(progress.is_lesson_complete("p-lesson", lesson))
  end)

  it("computes percent across registered lessons", function()
    two_ex_lesson()
    assert.are.equal(0, progress.percent())
    progress.record_exercise("p-lesson", "e1")
    assert.are.equal(50, progress.percent())
    progress.record_exercise("p-lesson", "e2")
    assert.are.equal(100, progress.percent())
  end)

  it("resets all progress", function()
    progress.record_exercise("p-lesson", "e1")
    progress.reset_all()
    assert.are.same({}, progress.load().lessons)
  end)

  it("honors persist_progress = false (no file written)", function()
    config.reset()
    config.setup({ persist_progress = false })
    progress.record_exercise("p-lesson", "e1")
    assert.are.equal(0, vim.fn.filereadable(tmp))
  end)
end)
