-- Lesson/exercise schema validation and normalization.
local M = {}

M.VALIDATOR_TYPES = {
  buffer = true,
  cursor_position = true,
  mode = true,
  selection = true,
  register = true,
  search = true,
  command = true,
  file = true,
  sequence = true,
  composite = true,
}

local function fail(fmt, ...)
  error(string.format(fmt, ...), 3)
end

local function is_str_list(v)
  if type(v) ~= "table" then
    return false
  end
  for i = 1, #v do
    if type(v[i]) ~= "string" then
      return false
    end
  end
  return true
end

local function check_validation(validation, ex_id)
  if type(validation) ~= "table" or type(validation.type) ~= "string" then
    fail("exercise %s: validation must be a table with a .type", ex_id)
  end
  if not M.VALIDATOR_TYPES[validation.type] then
    fail("exercise %s: unknown validator type '%s'", ex_id, validation.type)
  end
  if validation.type == "composite" then
    if type(validation.validations) ~= "table" or #validation.validations == 0 then
      fail("exercise %s: composite validation requires a non-empty .validations list", ex_id)
    end
    for _, sub in ipairs(validation.validations) do
      if type(sub) ~= "table" or not M.VALIDATOR_TYPES[sub.type] then
        fail("exercise %s: composite sub-validation is invalid", ex_id)
      end
    end
  end
end

-- Validates a raw lesson table and returns a normalized copy with defaults
-- filled in. Raises an error (level 3) on any schema violation.
function M.validate(lesson)
  if type(lesson) ~= "table" then
    fail("lesson must be a table")
  end
  if type(lesson.id) ~= "string" or lesson.id == "" then
    fail("lesson.id: non-empty string required")
  end
  if type(lesson.title) ~= "string" or lesson.title == "" then
    fail("lesson.title: non-empty string required")
  end
  if type(lesson.exercises) ~= "table" or #lesson.exercises == 0 then
    fail("lesson %s: exercises must be a non-empty list", lesson.id)
  end

  local normalized = {
    id = lesson.id,
    title = lesson.title,
    summary = lesson.summary or "",
    concept = lesson.concept or "",
    exercises = {},
  }

  local seen = {}
  for i, ex in ipairs(lesson.exercises) do
    if type(ex) ~= "table" then
      fail("lesson %s: exercise[%d] must be a table", lesson.id, i)
    end
    local ex_id = (type(ex.id) == "string" and ex.id ~= "") and ex.id or ("#" .. i)
    if type(ex.id) ~= "string" or ex.id == "" then
      fail("lesson %s: exercise[%d].id: non-empty string required", lesson.id, i)
    end
    if seen[ex.id] then
      fail("lesson %s: duplicate exercise id '%s'", lesson.id, ex.id)
    end
    seen[ex.id] = true

    if type(ex.instruction) ~= "string" or ex.instruction == "" then
      fail("exercise %s: instruction is required", ex_id)
    end
    if ex.initial_content ~= nil and not is_str_list(ex.initial_content) then
      fail("exercise %s: initial_content must be a list of strings", ex_id)
    end
    if ex.cursor ~= nil then
      if type(ex.cursor) ~= "table" or #ex.cursor ~= 2
        or type(ex.cursor[1]) ~= "number" or type(ex.cursor[2]) ~= "number" then
        fail("exercise %s: cursor must be {row, col}", ex_id)
      end
    end
    if ex.start_mode ~= nil and ex.start_mode ~= "normal" and ex.start_mode ~= "insert" then
      fail("exercise %s: start_mode must be 'normal' or 'insert'", ex_id)
    end
    if ex.hints ~= nil and not is_str_list(ex.hints) then
      fail("exercise %s: hints must be a list of strings", ex_id)
    end
    if ex.solution ~= nil then
      if type(ex.solution) ~= "table" then
        fail("exercise %s: solution must be a table { keys = ..., text = ... }", ex_id)
      end
      if ex.solution.keys ~= nil and type(ex.solution.keys) ~= "string" then
        fail("exercise %s: solution.keys must be a string", ex_id)
      end
    end
    check_validation(ex.validation, ex_id)

    normalized.exercises[i] = {
      id = ex.id,
      instruction = ex.instruction,
      initial_content = ex.initial_content or { "" },
      cursor = ex.cursor or { 1, 0 },
      start_mode = ex.start_mode or "normal",
      show_target = ex.show_target == true,
      validation = ex.validation,
      success_message = ex.success_message or "Correct!",
      hints = ex.hints or {},
      solution = ex.solution,
      file = ex.file == true,
      closes_buffer = ex.closes_buffer == true,
    }
  end

  return normalized
end

return M
