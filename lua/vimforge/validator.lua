-- Validation engine. Each validator is a pure function:
--
--     M.types[name](validation, ctx) -> boolean
--
-- where ctx is a snapshot of the relevant Neovim state, built by the runner:
--
--     ctx.lines              string[]  scratch buffer lines
--     ctx.cursor             {row, col} or nil (1-based row, 0-based col)
--     ctx.cursor_in_scratch  boolean   cursor is in the window showing the buffer
--     ctx.mode               mode code ("n", "i", "v", ...) or nil
--     ctx.selection          { start = {r, c}, finish = {r, c} } or nil
--     ctx.command_history    string[]  Ex commands entered this exercise
--     ctx.keys               string[]  recorded normal-mode keys
--     ctx.file_lines         string[]  temp file contents on disk, or nil
--     ctx.initial_lines      string[]  exercise.initial_content
--
-- The `register` and `search` validators read the live register via
-- vim.fn.getreg, which is stable and cheap at check time.
local M = {}

M.types = {}

local function normalize_lines(lines)
  local out = {}
  for _, l in ipairs(lines or {}) do
    out[#out + 1] = (l or ""):gsub("[%s]+$", "")
  end
  while #out > 0 and out[#out] == "" do
    table.remove(out)
  end
  return out
end

local function lines_equal(a, b)
  local na, nb = normalize_lines(a), normalize_lines(b)
  if #na ~= #nb then
    return false
  end
  for i = 1, #na do
    if na[i] ~= nb[i] then
      return false
    end
  end
  return true
end

M._normalize_lines = normalize_lines
M._lines_equal = lines_equal

local MODE_NAMES = {
  n = "normal",
  no = "operator-pending",
  i = "insert",
  ic = "insert",
  R = "replace",
  Rv = "replace",
  v = "visual",
  V = "visual-line",
  ["\x16"] = "visual-block",
  s = "select",
  S = "select-line",
  c = "cmdline",
  t = "terminal",
}

function M.mode_name(code)
  return MODE_NAMES[code] or code
end

-- buffer: full-buffer content match (trailing whitespace/blank lines ignored)
M.types.buffer = function(v, ctx)
  return lines_equal(ctx.lines, v.expected)
end

-- cursor_position: cursor exactly at v.position = {row, col}
M.types.cursor_position = function(v, ctx)
  if not ctx.cursor or not ctx.cursor_in_scratch then
    return false
  end
  return ctx.cursor[1] == v.position[1] and ctx.cursor[2] == v.position[2]
end

-- mode: current mode name matches v.expected (string or list of names)
M.types.mode = function(v, ctx)
  if not ctx.mode then
    return false
  end
  local name = M.mode_name(ctx.mode)
  if type(v.expected) == "table" then
    for _, e in ipairs(v.expected) do
      if name == e then
        return true
      end
    end
    return false
  end
  return name == v.expected
end

-- selection: visual selection spans v.start..v.finish (inclusive). When
-- allow_trailing_whitespace (default true) a selection that extends the
-- expected finish over trailing whitespace on the same line also passes.
M.types.selection = function(v, ctx)
  if not ctx.selection then
    return false
  end
  local s, f = ctx.selection.start, ctx.selection.finish
  local es, ef = v.start, v.finish
  if s[1] == es[1] and s[2] == es[2] and f[1] == ef[1] and f[2] == ef[2] then
    return true
  end
  if v.allow_trailing_whitespace ~= false
    and s[1] == es[1] and s[2] == es[2]
    and f[1] == ef[1] and f[2] >= ef[2] then
    local line = (ctx.lines or {})[ef[1]] or ""
    for c = ef[2], f[2] - 1 do
      local ch = line:sub(c + 1, c + 1)
      if ch ~= " " and ch ~= "\t" then
        return false
      end
    end
    return true
  end
  return false
end

-- register: contents of v.register (default unnamed '"') equal v.expected
M.types.register = function(v, ctx)
  local reg = v.register or "\""
  local val = vim.fn.getreg(reg)
  if v.trim ~= false then
    val = val:match("^%s*(.-)%s*$")
  end
  return val == v.expected
end

-- search: last search pattern (@/) equals v.pattern
M.types.search = function(v, ctx)
  return vim.fn.getreg("/") == v.pattern
end

-- command: every group in v.expected appeared in the Ex command history.
-- Groups accept common alias spellings (e.g. "w" matches :w/:write/:wq/:x).
local CMD_ALIASES = {
  w = { "w", "write", "wq", "writeq", "x" },
  q = { "q", "quit", "q!", "quit!" },
  wq = { "wq", "writeq", "x" },
  help = { "help", "h" },
}

M.types.command = function(v, ctx)
  local history = ctx.command_history or {}
  for _, expected in ipairs(v.expected) do
    local aliases = CMD_ALIASES[expected] or { expected }
    local found = false
    for _, cmd in ipairs(history) do
      for _, a in ipairs(aliases) do
        if cmd == a then
          found = true
          break
        end
      end
      if found then
        break
      end
    end
    if not found then
      return false
    end
  end
  return true
end

-- file: temp file on disk matches v.expected (file-backed exercises only)
M.types.file = function(v, ctx)
  if not ctx.file_lines then
    return false
  end
  return lines_equal(ctx.file_lines, v.expected)
end

-- sequence: one of v.allowed key sequences appears as an ordered
-- subsequence of the recorded keys (ctx.keys).
local function is_subsequence(needle, hay)
  local i = 1
  for j = 1, #hay do
    if hay[j] == needle[i] then
      i = i + 1
      if i > #needle then
        return true
      end
    end
  end
  return i > #needle
end

M.types.sequence = function(v, ctx)
  local keys = ctx.keys or {}
  for _, allowed in ipairs(v.allowed) do
    if is_subsequence(allowed, keys) then
      return true
    end
  end
  return false
end

-- composite: all sub-validations pass
M.types.composite = function(v, ctx)
  for _, sub in ipairs(v.validations) do
    if not M.check(sub, ctx) then
      return false
    end
  end
  return true
end

function M.check(validation, ctx)
  local fn = M.types[validation.type]
  if not fn then
    error("vimforge: unknown validator type '" .. tostring(validation.type) .. "'", 2)
  end
  return fn(validation, ctx) and true or false
end

return M
