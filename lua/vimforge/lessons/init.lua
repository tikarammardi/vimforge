-- Lesson registry: built-in lessons plus user-registered ones.
local M = {}

local lesson_mod = require("vimforge.lesson")

M._lessons = {}
M._by_id = {}
M._loaded = false
-- Test hook: override (or empty) the built-in list for isolated tests.
M._builtins_override = nil

-- Built-in lesson modules, in curriculum order. A module is added here once
-- it is implemented; load_builtins() is strict about every module listed.
local BUILTINS = {
  "vimforge.lessons.modes",
}

function M.add(lesson)
  local normalized = lesson_mod.validate(lesson)
  if M._by_id[normalized.id] then
    error("vimforge: lesson id already registered: " .. normalized.id)
  end
  table.insert(M._lessons, normalized)
  M._by_id[normalized.id] = normalized
  return normalized
end

-- Test hook: override the built-in list (pass {} to load none).
function M.set_builtins_for_test(names)
  M._builtins_override = names
end

function M.load_builtins()
  if M._loaded then
    return
  end
  M._loaded = true
  local list = M._builtins_override or BUILTINS
  for _, name in ipairs(list) do
    local ok, mod = pcall(require, name)
    if not ok then
      error("vimforge: failed to load lesson module '" .. name .. "': " .. tostring(mod), 2)
    end
    M.add(mod)
  end
end

function M.get(id)
  M.load_builtins()
  return M._by_id[id]
end

function M.all()
  M.load_builtins()
  return M._lessons
end

function M.next(lesson_id)
  M.load_builtins()
  for i, l in ipairs(M._lessons) do
    if l.id == lesson_id and M._lessons[i + 1] then
      return M._lessons[i + 1]
    end
  end
  return nil
end

-- Test hook.
function M.reset()
  M._lessons = {}
  M._by_id = {}
  M._loaded = false
end

return M
