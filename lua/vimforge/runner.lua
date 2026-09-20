-- The exercise runner: owns the scratch buffer, event wiring, the debounced
-- validation check, and the success/hint/advance/quit flows.
local M = {}

local state = require("vimforge.state")
local config = require("vimforge.config")
local validator = require("vimforge.validator")
local progress = require("vimforge.progress")
local lessons = require("vimforge.lessons")
local ui = require("vimforge.ui")

local AUGROUP = "VimForge"
local ns = vim.api.nvim_create_namespace("vimforge")

local pending_cmd_type = nil
local pending_cmd_line = nil

local function _stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function _index_of(lesson, exercise)
  for i, ex in ipairs(lesson.exercises) do
    if ex.id == exercise.id then
      return i
    end
  end
  return 1
end

local function _panel_width()
  return config.ensure().panel_width
end

-- Builds the validation context snapshot from live Neovim state.
function M._build_ctx()
  local buf = state.active.buf
  local lines = {}
  local valid = buf and vim.api.nvim_buf_is_valid(buf)
  if valid then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  local cursor, in_scratch = nil, false
  if valid then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(win) == buf then
        cursor = vim.api.nvim_win_get_cursor(win)
        in_scratch = (win == vim.api.nvim_get_current_win())
        break
      end
    end
  end

  local mode
  if valid and vim.api.nvim_win_get_buf(0) == buf then
    mode = vim.api.nvim_get_mode().mode
  end

  local selection
  if mode and (mode == "v" or mode == "V" or mode == "\x16") and valid then
    local srow, scol = vim.api.nvim_buf_get_mark(buf, "<")
    local erow, ecol = vim.api.nvim_buf_get_mark(buf, ">")
    if srow > 0 and erow > 0 then
      selection = { start = { srow, scol }, finish = { erow, ecol } }
    end
  end

  local file_lines
  if state.active.temp_file and vim.fn.filereadable(state.active.temp_file) == 1 then
    file_lines = vim.fn.readfile(state.active.temp_file)
  end

  return {
    lines = lines,
    cursor = cursor,
    cursor_in_scratch = in_scratch,
    mode = mode,
    selection = selection,
    command_history = state.active.commands,
    keys = state.active.keys,
    file_lines = file_lines,
    initial_lines = state.active.exercise.initial_content,
  }
end

local function _user_acted(ctx)
  if #state.active.commands > 0 or #state.active.keys > 0 then
    return true
  end
  return not validator._lines_equal(ctx.lines, state.active.exercise.initial_content)
end

function M._check()
  if not state.is_active() then
    return
  end
  local ctx = M._build_ctx()
  if validator.check(state.active.exercise.validation, ctx) then
    M._on_success()
  elseif _user_acted(ctx) then
    state.active.attempts = state.active.attempts + 1
  end
end

local function schedule_check()
  if not state.is_active() then
    return
  end
  -- Timer callbacks run in a "fast event" context where most nvim.api calls
  -- are forbidden, so the actual check is deferred to the main loop.
  _stop_timer()
  state.timer = vim.uv.new_timer()
  state.timer:start(config.ensure().check_delay, 0, function()
    _stop_timer()
    vim.schedule(M._check)
  end)
end

local function _clear_extmarks()
  for _, id in ipairs(state.active.extmarks) do
    if state.active.buf and vim.api.nvim_buf_is_valid(state.active.buf) then
      pcall(vim.api.nvim_buf_del_extmark, state.active.buf, ns, id)
    end
  end
  state.active.extmarks = {}
end

-- Creates the scratch buffer for an exercise. Returns the buffer id.
local function _create_scratch(exercise, lesson)
  local buf
  if exercise.file then
    local cfg = config.ensure()
    local dir = cfg.data_dir .. "/tmp"
    vim.fn.mkdir(dir, "p")
    local path = dir .. "/" .. lesson.id .. "-" .. exercise.id .. ".txt"
    vim.fn.writefile(exercise.initial_content, path)
    state.active.temp_file = path
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, path)
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, exercise.initial_content)
  end
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  return buf
end

-- Records normal-mode keys for exercises using the sequence validator.
local function _collect_seq_keys(validation, acc)
  if validation.type == "sequence" then
    for _, allowed in ipairs(validation.allowed) do
      for _, k in ipairs(allowed) do
        acc[k] = true
      end
    end
  elseif validation.type == "composite" then
    for _, sub in ipairs(validation.validations) do
      _collect_seq_keys(sub, acc)
    end
  end
  return acc
end

local function _setup_sequence(exercise)
  local acc = _collect_seq_keys(exercise.validation, {})
  local buf = state.active.buf
  for k in pairs(acc) do
    local handler
    handler = function()
      table.insert(state.active.keys, k)
      -- Remove the mapping so the re-fed raw key executes natively, then
      -- re-arm it once that key has been consumed.
      vim.keymap.del("n", k, { buffer = buf })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "n", false)
      vim.defer_fn(function()
        if state.active.buf == buf and vim.api.nvim_buf_is_valid(buf) then
          vim.keymap.set("n", k, handler, { buffer = buf })
        end
      end, 0)
    end
    vim.keymap.set("n", k, handler, { buffer = buf })
  end
end

local function on_cmdline_enter()
  pending_cmd_type = vim.fn.getcmdtype()
  pending_cmd_line = vim.fn.getcmdline()
end

local function on_cmdline_leave()
  -- CmdlineLeave is a fast event; defer the buffer comparison and recording.
  local t, line = pending_cmd_type, pending_cmd_line
  pending_cmd_type = nil
  pending_cmd_line = nil
  vim.schedule(function()
    if t == ":" and state.active.buf and vim.api.nvim_win_get_buf(0) == state.active.buf then
      local l = (line or ""):gsub("^:", "")
      local first = l:match("^[^%s]+")
      if first and first ~= "" then
        table.insert(state.active.commands, first)
      end
    end
    schedule_check()
  end)
end

local function on_buf_delete()
  -- The scratch buffer was closed (e.g. a :q exercise). Run a final check,
  -- deferred out of the fast-event context.
  vim.schedule(M._check)
end

local function _setup_autocmds(buf)
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  local trigger_events = {
    "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI",
    "ModeChanged", "TextYankPost",
  }
  vim.api.nvim_create_autocmd(trigger_events, {
    group = AUGROUP,
    callback = schedule_check,
  })
  vim.api.nvim_create_autocmd("CmdlineEnter", { group = AUGROUP, callback = on_cmdline_enter })
  vim.api.nvim_create_autocmd("CmdlineLeave", { group = AUGROUP, callback = on_cmdline_leave })
  vim.api.nvim_create_autocmd("BufDelete", { group = AUGROUP, buffer = buf, callback = on_buf_delete })
end

function M._panel_rows(overrides)
  overrides = overrides or {}
  local lesson = state.active.lesson
  local ex = state.active.exercise
  local w = _panel_width() - 2
  local rows = {}
  rows[#rows + 1] = { text = lesson.title, hl = "VimForgeTitle" }
  if lesson.concept ~= "" then
    for _, line in ipairs(ui.wrap(lesson.concept, w)) do
      rows[#rows + 1] = { text = "  " .. line, hl = "VimForgeDim" }
    end
  end
  rows[#rows + 1] = {
    text = string.format("Exercise %d of %d", state.active.exercise_index, #lesson.exercises),
    hl = "VimForgeProgress",
  }
  rows[#rows + 1] = { text = "" }
  for _, line in ipairs(ui.wrap(ex.instruction, w)) do
    rows[#rows + 1] = { text = "  " .. line, hl = "VimForgeInstruction" }
  end
  rows[#rows + 1] = { text = "" }
  if overrides.feedback then
    for _, line in ipairs(ui.wrap(overrides.feedback, w)) do
      rows[#rows + 1] = { text = "  " .. line, hl = overrides.feedback_hl }
    end
    if overrides.sub_feedback then
      rows[#rows + 1] = { text = "  " .. overrides.sub_feedback, hl = overrides.sub_feedback_hl or "VimForgeDim" }
    end
  else
    rows[#rows + 1] = { text = "  ? hint    q quit", hl = "VimForgeDim" }
  end
  return rows
end

local function _render_panel()
  if state.active.panel_buf and vim.api.nvim_buf_is_valid(state.active.panel_buf) then
    ui.render_buffer(state.active.panel_buf, M._panel_rows())
  end
end

local function _render_panel_feedback(feedback, hl, sub_feedback)
  if state.active.panel_buf and vim.api.nvim_buf_is_valid(state.active.panel_buf) then
    ui.render_buffer(state.active.panel_buf, M._panel_rows({
      feedback = feedback,
      feedback_hl = hl,
      sub_feedback = sub_feedback,
    }))
  end
end

-- Clears the current exercise's autocmds, extmarks, timer and temp file.
-- Deliberately does NOT delete the scratch buffer (the caller decides when it
-- is safe to do so) and does not touch the panel or window layout.
function M._teardown_exercise()
  _stop_timer()
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  _clear_extmarks()
  if state.active.temp_file and vim.fn.filereadable(state.active.temp_file) == 1 then
    pcall(vim.fn.delete, state.active.temp_file)
  end
  state.active.temp_file = nil
end

function M._delete_scratch()
  if state.active.buf and vim.api.nvim_buf_is_valid(state.active.buf) then
    pcall(vim.api.nvim_buf_delete, state.active.buf, { force = true })
  end
  state.active.buf = nil
end

-- Full exit: tear down the exercise, close the panel, restore the learner's
-- previous buffer.
function M._quit_cleanup()
  M._teardown_exercise()
  M._delete_scratch()
  if state.active.panel_win and vim.api.nvim_win_is_valid(state.active.panel_win) then
    -- Never close the last window in the tabpage.
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
      vim.api.nvim_win_close(state.active.panel_win, true)
    end
  end
  state.active.panel_win = nil
  state.active.panel_buf = nil
  if state.active.prev_buf and vim.api.nvim_buf_is_valid(state.active.prev_buf) then
    pcall(vim.api.nvim_set_current_buf, state.active.prev_buf)
  end
  state.active.prev_buf = nil
  state.active.prev_win = nil
  state.active.practice_win = nil
  state.active.lesson = nil
  state.active.lesson_id = nil
  state.active.status = "idle"
end

function M._on_success()
  if state.active.status == "success" then
    return
  end
  _stop_timer()
  state.active.status = "success"
  local lesson = state.active.lesson
  local ex = state.active.exercise
  progress.record_exercise(lesson.id, ex.id, {
    attempts = state.active.attempts,
    hints = state.active.hints_shown,
  })
  _clear_extmarks()

  local is_last = state.active.exercise_index >= #lesson.exercises
  local msg, sub
  if is_last then
    msg = "Lesson complete!"
    sub = "Press <Enter> to continue."
  else
    msg = ex.success_message
    sub = "Press <Enter> for the next exercise."
  end
  _render_panel_feedback(msg, "VimForgeSuccess", sub)

  if state.active.buf and vim.api.nvim_buf_is_valid(state.active.buf) then
    vim.keymap.set("n", "<CR>", M.next, { buffer = state.active.buf })
  else
    -- The buffer was closed by the exercise itself (e.g. :q): auto-advance.
    vim.defer_fn(function()
      M.next()
    end, 900)
  end
end

function M.start_exercise(exercise)
  M._teardown_exercise()

  local lesson = state.active.lesson
  state.active.exercise = exercise
  state.active.exercise_index = _index_of(lesson, exercise)
  state.active.status = "active"
  state.active.attempts = 0
  state.active.hints_shown = 0
  state.active.keys = {}
  state.active.commands = {}

  local old_buf = state.active.buf
  local buf = _create_scratch(exercise, lesson)
  state.active.buf = buf
  -- Point the practice window at the new buffer before dropping the old one,
  -- so we never delete a buffer that is still displayed.
  vim.api.nvim_set_current_win(state.active.practice_win)
  vim.api.nvim_set_current_buf(buf)
  if old_buf and old_buf ~= buf and vim.api.nvim_buf_is_valid(old_buf) then
    pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
  end

  local row = math.min(exercise.cursor[1], #exercise.initial_content)
  vim.api.nvim_win_set_cursor(0, { row, exercise.cursor[2] })

  if exercise.start_mode == "insert" then
    vim.cmd("startinsert!")
  end

  if exercise.show_target then
    local pos
    local v = exercise.validation
    if v.type == "cursor_position" then
      pos = v.position
    elseif v.type == "composite" then
      for _, sub in ipairs(v.validations) do
        if sub.type == "cursor_position" then
          pos = sub.position
          break
        end
      end
    end
    if pos then
      state.active.extmarks[#state.active.extmarks + 1] = ui.set_target(buf, pos[1], pos[2])
    end
  end

  _render_panel()
  vim.keymap.set("n", "?", M.hint, { buffer = buf })
  vim.keymap.set("n", "q", M.quit, { buffer = buf })
  _setup_sequence(exercise)
  _setup_autocmds(buf)
  schedule_check()
end

-- Starts a lesson from its first incomplete exercise (or the first one).
function M.start(lesson_id)
  config.ensure()
  ui.setup_highlights()
  local lesson = lessons.get(lesson_id)
  if not lesson then
    vim.notify("vimforge: unknown lesson '" .. tostring(lesson_id) .. "'", vim.log.levels.ERROR)
    return
  end
  -- Close any open selector from a previous run.
  if state.active.selector_win and vim.api.nvim_win_is_valid(state.active.selector_win) then
    vim.api.nvim_win_close(state.active.selector_win, true)
    state.active.selector_win = nil
    state.active.selector_buf = nil
  end
  state.active.lesson = lesson
  state.active.lesson_id = lesson.id

  state.active.prev_win = vim.api.nvim_get_current_win()
  state.active.prev_buf = vim.api.nvim_win_get_buf(0)
  -- The learner's own window becomes the practice window.
  state.active.practice_win = state.active.prev_win

  if not (state.active.panel_win and vim.api.nvim_win_is_valid(state.active.panel_win)) then
    local win, buf = ui.open_panel()
    state.active.panel_win = win
    state.active.panel_buf = buf
    -- open_panel may leave focus in the new split; return to the learner's
    -- window so the practice buffer opens there.
    vim.api.nvim_set_current_win(state.active.prev_win)
  end

  local start_idx = 1
  for i, ex in ipairs(lesson.exercises) do
    local data = progress.load()
    local l = data.lessons[lesson.id]
    local e = l and l.exercises[ex.id]
    if not (e and e.completed) then
      start_idx = i
      break
    end
    start_idx = i
  end
  M.start_exercise(lesson.exercises[start_idx])
end

function M.next()
  if state.active.status ~= "success" then
    return
  end
  local lesson = state.active.lesson
  local idx = state.active.exercise_index
  if idx < #lesson.exercises then
    M.start_exercise(lesson.exercises[idx + 1])
  else
    progress.mark_lesson_complete(lesson.id)
    M._quit_cleanup()
    M.selector()
  end
end

function M.restart()
  if not state.active.lesson then
    return
  end
  local lesson = state.active.lesson
  local idx = state.active.exercise_index
  if state.active.exercise then
    M.start_exercise(lesson.exercises[idx])
  end
end

function M.hint()
  if state.active.status ~= "active" then
    return
  end
  local ctx = M._build_ctx()
  if validator.check(state.active.exercise.validation, ctx) then
    M._on_success()
    return
  end
  local ex = state.active.exercise
  state.active.hints_shown = state.active.hints_shown + 1
  local hint
  if state.active.hints_shown <= #ex.hints then
    hint = ex.hints[state.active.hints_shown]
  elseif ex.solution and ex.solution.text then
    hint = "Solution: " .. ex.solution.text
  elseif ex.solution and ex.solution.keys then
    hint = "Try: " .. ex.solution.keys
  else
    hint = "Keep going — re-read the instruction."
  end
  _render_panel_feedback(hint, "VimForgeHint")
end

-- Leaves the lesson and restores the learner's previous window/buffer. The
-- selector is opened explicitly (:VimForge) or on lesson completion.
function M.quit()
  M._quit_cleanup()
end

-- Opens the lesson selector float.
function M.selector()
  ui.setup_highlights()
  local all = lessons.all()

  local function build_rows(selected)
    local rows = {}
    rows[#rows + 1] = { text = "  V I M F O R G E", hl = "VimForgeTitle" }
    rows[#rows + 1] = { text = "  Learn Vim by using real Vim.", hl = "VimForgeDim" }
    rows[#rows + 1] = { text = "" }
    for i, l in ipairs(all) do
      local done = progress.is_lesson_complete(l.id, l)
      local icon = done and "x" or " "
      local marker = (i == selected) and "▶" or " "
      local hl = (i == selected) and "VimForgeSelected" or (done and "VimForgeSuccess" or "VimForgeInstruction")
      rows[#rows + 1] = {
        text = string.format("  %s [%s] %d. %s", marker, icon, i, l.title),
        hl = hl,
      }
    end
    rows[#rows + 1] = { text = "" }
    rows[#rows + 1] = { text = string.format("  Progress: %d%%", progress.percent()), hl = "VimForgeProgress" }
    rows[#rows + 1] = { text = "" }
    rows[#rows + 1] = { text = "  j/k move    <Enter> start    q close", hl = "VimForgeDim" }
    return rows
  end

  local selected = 1
  local win, buf = ui.show_selector(build_rows(selected))
  state.active.selector_win = win
  state.active.selector_buf = buf

  local function redraw()
    if vim.api.nvim_buf_is_valid(buf) then
      ui.render_buffer(buf, build_rows(selected))
    end
  end

  vim.keymap.set("n", "j", function()
    selected = math.min(#all, selected + 1)
    redraw()
  end, { buffer = buf })
  vim.keymap.set("n", "k", function()
    selected = math.max(1, selected - 1)
    redraw()
  end, { buffer = buf })
  vim.keymap.set("n", "<CR>", function()
    M._quit_cleanup()
    M.start(all[selected].id)
  end, { buffer = buf })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    state.active.selector_win = nil
    state.active.selector_buf = nil
  end, { buffer = buf })
end

return M
