-- Durable progress: JSON at <data_dir>/progress.json.
--
-- Shape:
--   { lessons = { [lesson_id] = {
--       completed = boolean,
--       completed_at = number,
--       exercises = { [ex_id] = { completed, completed_at, attempts, hints } }
--   } } }
local M = {}

local fn = vim.fn

-- Test override; nil means "derive from config".
M._path = nil

function M.path()
  if M._path then
    return M._path
  end
  local config = require("vimforge.config").ensure()
  return config.data_dir .. "/progress.json"
end

function M.set_test_path(p)
  M._path = p
end

function M.load()
  local p = M.path()
  if fn.filereadable(p) == 1 then
    local raw = table.concat(fn.readfile(p), "\n")
    local ok, data = pcall(fn.json_decode, raw)
    if ok and type(data) == "table" then
      data.lessons = data.lessons or {}
      return data
    end
  end
  return { lessons = {} }
end

function M.save(data)
  local p = M.path()
  local dir = fn.fnamemodify(p, ":h")
  if fn.isdirectory(dir) ~= 1 then
    fn.mkdir(dir, "p")
  end
  fn.writefile({ fn.json_encode(data) }, p)
end

local function persist()
  return require("vimforge.config").config.persist_progress
end

function M.record_exercise(lesson_id, ex_id, opts)
  opts = opts or {}
  local data = M.load()
  local l = data.lessons[lesson_id] or { exercises = {} }
  l.exercises = l.exercises or {}
  local e = l.exercises[ex_id] or {}
  e.completed = true
  e.completed_at = os.time()
  e.attempts = opts.attempts or e.attempts or 0
  e.hints = opts.hints or e.hints or 0
  l.exercises[ex_id] = e
  data.lessons[lesson_id] = l
  if persist() then
    M.save(data)
  end
  return data
end

function M.mark_lesson_complete(lesson_id)
  local data = M.load()
  local l = data.lessons[lesson_id] or { exercises = {} }
  l.completed = true
  l.completed_at = os.time()
  data.lessons[lesson_id] = l
  if persist() then
    M.save(data)
  end
  return data
end

function M.is_lesson_complete(lesson_id, lesson)
  local data = M.load()
  local l = data.lessons[lesson_id]
  if not l then
    return false
  end
  for _, ex in ipairs(lesson.exercises) do
    local e = (l.exercises or {})[ex.id]
    if not e or not e.completed then
      return false
    end
  end
  return true
end

function M.reset_all()
  local p = M.path()
  if fn.filereadable(p) == 1 then
    fn.delete(p)
  end
end

-- Percentage of all exercises completed across every registered lesson.
function M.percent()
  local registry = require("vimforge.lessons")
  local data = M.load()
  local total, done = 0, 0
  for _, lesson in ipairs(registry.all()) do
    for _, ex in ipairs(lesson.exercises) do
      total = total + 1
      local l = data.lessons[lesson.id]
      local e = l and (l.exercises or {})[ex.id]
      if e and e.completed then
        done = done + 1
      end
    end
  end
  if total == 0 then
    return 0
  end
  return math.floor(done / total * 100)
end

return M
