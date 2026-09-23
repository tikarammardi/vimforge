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
  if mode and (mode == "v" or mode == "V" or mode == "\x16") and valid and cursor then
    -- Neovim only sets the < and > marks when visual mode ENDS, so a live
    -- selection is derived from the last normal-mode cursor position (the
    -- anchor) plus the current cursor (the extending end), shaped by the
    -- visual flavor: charwise is the plain span, linewise covers whole
    -- lines, blockwise the rectangle between the two corners.
    local start, finish
    if state.active.selection_anchor then
      local a = state.active.selection_anchor
      if mode == "V" then
        start = { math.min(a[1], cursor[1]), 0 }
        local er = math.max(a[1], cursor[1])
        local line = (lines or {})[er] or ""
        finish = { er, math.max(#line - 1, 0) }
      elseif mode == "\x16" then
        start = { math.min(a[1], cursor[1]), math.min(a[2], cursor[2]) }
        finish = { math.max(a[1], cursor[1]), math.max(a[2], cursor[2]) }
      else
        start, finish = a, cursor
      end
    else
      local lm = vim.api.nvim_buf_get_mark(buf, "<")
      local rm = vim.api.nvim_buf_get_mark(buf, ">")
      if type(lm) == "table" and lm[1] > 0 and type(rm) == "table" and rm[1] > 0 then
        start, finish = { lm[1], lm[2] }, { rm[1], rm[2] }
      end
    end
    if start then
      if (start[1] > finish[1]) or (start[1] == finish[1] and start[2] > finish[2]) then
        start, finish = finish, start
      end
      selection = { start = start, finish = finish }
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
    -- :edit! performs a real file load (nvim_buf_set_name alone leaves the
    -- buffer empty) and makes the file contents the buffer's undo origin, so
    -- `u` restores the initial content exactly as in a real file. :edit!
    -- loads into the current window's buffer, so make sure the practice
    -- window is current (never the panel window).
    if state.active.practice_win and vim.api.nvim_win_is_valid(state.active.practice_win)
      and vim.api.nvim_get_current_win() ~= state.active.practice_win then
      vim.api.nvim_set_current_win(state.active.practice_win)
    end
    vim.cmd("silent! edit! " .. vim.fn.fnameescape(path))
    buf = vim.api.nvim_get_current_buf()
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

-- Tracks the last cursor position in NORMAL mode so a live visual selection
-- can be derived. Neovim's < and > marks are only written when visual mode
-- ENDS, so the anchor is where the cursor was in normal mode when v/V/<C-v>
-- was pressed. v/V/<C-v> are never intercepted (a keymap + re-feed corrupts
-- key bursts like "viw", because the re-queued v lands after the rest of the
-- burst in the typeahead queue); the anchor is captured via CursorMoved /
-- ModeChanged instead.
local function _setup_visual_anchor(exercise)
  local needed = false
  local function collect(validation)
    if validation.type == "selection" then
      needed = true
    elseif validation.type == "composite" then
      for _, sub in ipairs(validation.validations) do
        collect(sub)
      end
    end
  end
  collect(exercise.validation)
  if not needed then
    return
  end
  local function record()
    -- Only the practice buffer matters; ignore cursor moves in the panel.
    if not (state.active.buf and vim.api.nvim_win_get_buf(0) == state.active.buf) then
      return
    end
    local m = vim.api.nvim_get_mode().mode
    if m == "n" or m == "no" then
      local c = vim.api.nvim_win_get_cursor(0)
      state.active.selection_anchor = { c[1], c[2] }
    end
  end
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
    group = AUGROUP,
    callback = record,
  })
end

local function on_cmdline_enter()
  pending_cmd_type = vim.fn.getcmdtype()
end

local function on_cmdline_leave()
  -- CmdlineLeave is a fast event; defer the buffer comparison and recording.
  -- The command text is only complete at LEAVE (getcmdline() at Enter is
  -- empty for a fresh ":"), so capture it here.
  local t, line = pending_cmd_type, vim.fn.getcmdline()
  -- Capture the current buffer now: for :q/:wq the scratch buffer is gone by
  -- the time the deferred closure runs, so the comparison must use this.
  -- winbufnr(0), not bufnr(0): the latter returns -1 in the CmdlineLeave
  -- fast-event context (observed), winbufnr(0) is stable.
  local curbuf = vim.fn.winbufnr(0)
  pending_cmd_type = nil
  vim.schedule(function()
    if t == ":" and state.active.buf and curbuf == state.active.buf then
      local l = (line or ""):gsub("^:", "")
      -- Strip a leading range ("1,3s/a/b/" -> "s/a/b/").
      l = l:gsub("^[%d.$][%d.,$]*", "")
      -- The command token ends at whitespace or "/": ":s/cat/dog/" records
      -- "s", not the whole substitution.
      local first = l:match("^[^%s/]+")
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
    rows[#rows + 1] = { text = "  F1 hint   q quit", hl = "VimForgeDim" }
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

-- A :q/:wq exercise closes the practice window when the scratch buffer was
-- the last listed buffer: Vim closes the window instead of unlisting the
-- buffer (the scratch survives, listed, until the next exercise deletes it).
-- Recreate the practice window to the left of the panel and re-assert the
-- panel width.
local function _ensure_practice_window()
  if state.active.practice_win and vim.api.nvim_win_is_valid(state.active.practice_win) then
    return
  end
  local panel_buf = state.active.panel_buf
  local buf = (panel_buf and vim.api.nvim_buf_is_valid(panel_buf))
    and panel_buf or vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_open_win(buf, true, { split = "left" })
  state.active.practice_win = win
  pcall(vim.api.nvim_win_set_width, state.active.panel_win,
    math.min(config.ensure().panel_width, math.floor(vim.o.columns * 0.4)))
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

  -- <CR> advances only while the learner is actually IN the scratch. A
  -- :q/:wq exercise can end with the scratch unlisted but the practice
  -- window alive (Vim falls back to another listed buffer), or — when the
  -- scratch was the LAST listed buffer — the practice window CLOSED while
  -- the scratch buffer SURVIVES listed (BufDelete never fires). In both
  -- cases there is nothing to press <CR> in: auto-advance.
  local in_scratch = state.active.buf
    and vim.api.nvim_buf_is_valid(state.active.buf)
    and vim.api.nvim_win_get_buf(0) == state.active.buf
  if in_scratch then
    local buf = state.active.buf
    vim.keymap.set("n", "<CR>", M.next, { buffer = buf })
    -- Selection exercises succeed while still in VISUAL mode; <CR> there
    -- must advance too (Vim's default would just extend the selection).
    -- The keymap API only accepts the charwise "v" shortname, so the
    -- visual mapping is created via Ex. In Neovim :vnoremap covers all
    -- three visual flavors (:gmap/:xmap are separate in Vim). The only
    -- valid buffer-local form is bare <buffer>, issued with the scratch
    -- buffer current — which it is, since the current window displays it.
    -- (Never force the current buffer to get here: the current window may
    -- be the panel, and switching it would wipe the panel buffer.)
    vim.cmd("vnoremap <buffer> <CR> <Cmd>lua require('vimforge.runner').next()<CR>")
  else
    -- The exercise closed or unlisted its own buffer (e.g. :q): auto-advance.
    vim.defer_fn(function()
      M.next()
    end, 900)
  end
end

function M.start_exercise(exercise)
  M._teardown_exercise()
  _ensure_practice_window()

  local lesson = state.active.lesson
  state.active.exercise = exercise
  state.active.exercise_index = _index_of(lesson, exercise)
  state.active.status = "active"
  state.active.attempts = 0
  state.active.hints_shown = 0
  state.active.keys = {}
  state.active.commands = {}
  state.active.selection_anchor = nil

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
  -- Seed the visual-selection anchor with the initial (clamped) cursor so it
  -- is correct even if the user presses v before any CursorMoved fires.
  local c0 = vim.api.nvim_win_get_cursor(0)
  state.active.selection_anchor = { c0[1], c0[2] }

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
  -- F1 (Vim's canonical help key), not "?": the latter is a real Vim key
  -- (backward search) that exercises may need.
  vim.keymap.set("n", "<F1>", M.hint, { buffer = buf })
  vim.keymap.set("n", "q", M.quit, { buffer = buf })
  _setup_sequence(exercise)
  -- _setup_autocmds clears AUGROUP, so the anchor recorder must be created
  -- after it.
  _setup_autocmds(buf)
  _setup_visual_anchor(exercise)
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
  -- A selection exercise can succeed with the buffer in VISUAL mode; the
  -- visual state must not leak into the next exercise's fresh buffer.
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\x16" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
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
