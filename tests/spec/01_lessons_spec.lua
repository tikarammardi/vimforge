local lesson = require("vimforge.lesson")
local registry = require("vimforge.lessons")

local function valid_exercise(id)
  return {
    id = id or "ex1",
    instruction = "do the thing",
    validation = { type = "buffer", expected = { "hello" } },
  }
end

local function valid_lesson(overrides)
  local l = {
    id = "test-lesson",
    title = "Test Lesson",
    exercises = { valid_exercise() },
  }
  for k, v in pairs(overrides or {}) do
    l[k] = v
  end
  return l
end

describe("lesson schema validation", function()
  it("normalizes a minimal valid lesson with defaults", function()
    local l = lesson.validate(valid_lesson())
    assert.are.equal("test-lesson", l.id)
    assert.are.equal("Test Lesson", l.title)
    assert.are.equal("", l.summary)
    assert.are.equal("", l.concept)
    assert.are.same({ "" }, l.exercises[1].initial_content)
    assert.are.same({ 1, 0 }, l.exercises[1].cursor)
    assert.are.equal("normal", l.exercises[1].start_mode)
    assert.are.equal("Correct!", l.exercises[1].success_message)
    assert.are.same({}, l.exercises[1].hints)
    assert.is_false(l.exercises[1].file)
  end)

  it("rejects a lesson without an id", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({ id = "" }))
    end)
  end)

  it("rejects a lesson without exercises", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({ exercises = {} }))
    end)
  end)

  it("rejects an exercise without an instruction", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({
        exercises = { { id = "a", validation = { type = "buffer", expected = {} } } },
      }))
    end)
  end)

  it("rejects an unknown validator type", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({
        exercises = { { id = "a", instruction = "x", validation = { type = "nope" } } },
      }))
    end)
  end)

  it("rejects a composite without sub-validations", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({
        exercises = { { id = "a", instruction = "x", validation = { type = "composite" } } },
      }))
    end)
  end)

  it("rejects non-string initial_content", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({
        exercises = { { id = "a", instruction = "x", initial_content = { 42 },
          validation = { type = "buffer", expected = {} } } },
      }))
    end)
  end)

  it("rejects a bad start_mode", function()
    assert.has_error(function()
      lesson.validate(valid_lesson({
        exercises = { { id = "a", instruction = "x", start_mode = "visual",
          validation = { type = "buffer", expected = {} } } },
      }))
    end)
  end)

  it("accepts every documented validator type", function()
    for _, t in pairs({ "buffer", "cursor_position", "mode", "selection",
      "register", "search", "command", "file", "sequence", "composite" }) do
      local validation = { type = t }
      if t == "composite" then
        validation.validations = { { type = "buffer", expected = {} } }
      end
      local l = lesson.validate(valid_lesson({
        exercises = { { id = "a", instruction = "x", validation = validation } },
      }))
      assert.are.equal(t, l.exercises[1].validation.type)
    end
  end)
end)

describe("lesson registry", function()
  before_each(function()
    registry.reset()
    registry.set_builtins_for_test({})
  end)

  after_each(function()
    registry.set_builtins_for_test(nil)
    registry.reset()
  end)

  it("adds and retrieves lessons", function()
    local l = registry.add(valid_lesson())
    assert.are.equal("test-lesson", l.id)
    assert.is_same(l, registry.get("test-lesson"))
    assert.are.equal(1, #registry.all())
  end)

  it("rejects duplicate lesson ids", function()
    registry.add(valid_lesson())
    assert.has_error(function()
      registry.add(valid_lesson())
    end)
  end)

  it("returns the next lesson in curriculum order", function()
    registry.add(valid_lesson())
    registry.add({ id = "second", title = "Second",
      exercises = { valid_exercise() } })
    local nxt = registry.next("test-lesson")
    assert.are.equal("second", nxt.id)
    assert.is_nil(registry.next("second"))
  end)

  it("keeps insertion order in all()", function()
    registry.add({ id = "b", title = "B", exercises = { valid_exercise() } })
    registry.add({ id = "a", title = "A", exercises = { valid_exercise() } })
    local all = registry.all()
    assert.are.equal("b", all[1].id)
    assert.are.equal("a", all[2].id)
  end)
end)
