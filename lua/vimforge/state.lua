-- Per-session (in-memory) state for the active lesson/exercise. Nothing here
-- is persisted; progress.lua handles durable state.
local M = {}

M.active = {
  lesson = nil,
  lesson_id = nil,
  exercise_index = 0,
  exercise = nil,
  -- "idle" | "active" | "success"
  status = "idle",
  attempts = 0,
  hints_shown = 0,
  -- recorded normal-mode keys (sequence validator)
  keys = {},
  -- recorded Ex commands (command validator)
  commands = {},
  -- last cursor position in normal mode; < and > marks are only set when
  -- visual mode ENDS, so a live selection is derived from this anchor plus
  -- the current cursor
  selection_anchor = nil,
  -- scratch buffer id for the current exercise
  buf = nil,
  -- temp file path for file-backed exercises
  temp_file = nil,
  -- instruction panel window/buffer
  panel_win = nil,
  panel_buf = nil,
  -- window that displays the scratch (practice) buffer
  practice_win = nil,
  -- window/buffer to restore on exit
  prev_win = nil,
  prev_buf = nil,
  -- extmark ids to clean up
  extmarks = {},
}

M.timer = nil

local function clear_exercise()
  M.active.exercise_index = 0
  M.active.exercise = nil
  M.active.status = "idle"
  M.active.attempts = 0
  M.active.hints_shown = 0
  M.active.keys = {}
  M.active.commands = {}
  M.active.selection_anchor = nil
  M.active.buf = nil
  M.active.temp_file = nil
  M.active.extmarks = {}
end

function M.reset_exercise()
  clear_exercise()
end

function M.reset_all()
  M.active.lesson = nil
  M.active.lesson_id = nil
  M.active.panel_win = nil
  M.active.panel_buf = nil
  M.active.practice_win = nil
  M.active.prev_win = nil
  M.active.prev_buf = nil
  clear_exercise()
end

function M.is_active()
  return M.active.status == "active" or M.active.status == "success"
end

return M
