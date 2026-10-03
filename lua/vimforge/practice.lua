-- Practice: drill random tasks from a skill pool, vim-hero style.
--
-- A task is an exercise (same schema as lesson exercises) plus a .category.
-- A session runs tasks back to back with auto-advance, in one of three
-- modes:
--   goal    complete N tasks (default 10)
--   time    as many as you can in 60 seconds
--   endless until you quit with q
--
-- Everything is local and free — no paywall.
local M = {}

local lesson_mod = require("vimforge.lesson")

M.CATEGORIES = { "movement", "insertion", "editing", "text-objects", "visual" }
M.MODES = { "goal", "time", "endless" }
M.GOAL_DEFAULT = 10
M.TIME_LIMIT_MS = 60000

-- Test hook: override task selection (signature: function(category, exclude_id)).
M._pick = nil

local function task(id, category, instruction, initial_content, cursor, validation, solution, file)
  return {
    id = id,
    category = category,
    instruction = instruction,
    initial_content = initial_content,
    cursor = cursor or { 1, 0 },
    validation = validation,
    solution = solution,
    success_message = "Correct!",
    hints = {},
    -- file-backed scratch (real temp file) so `u` undoes to the initial
    -- content exactly like in a real file (see runner._create_scratch).
    file = file == true,
  }
end

local TASKS = {
  movement = {
    task("mv-jj", "movement", "Move down exactly two lines with jj.",
      { "one", "two", "three" }, { 1, 0 },
      { type = "cursor_position", position = { 3, 0 } },
      { keys = "jj", text = "Press j twice." }),
    task("mv-lllll", "movement", "Move right five characters with lllll (the cursor lands in column 5).",
      { "hello world" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 5 } },
      { keys = "lllll", text = "Press l five times." }),
    task("mv-w", "movement", "Move to the start of the next word with w.",
      { "one fish two" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 4 } },
      { keys = "w", text = "Press w." }),
    task("mv-b", "movement", "Move back to the start of the previous word with b.",
      { "one fish two" }, { 1, 4 },
      { type = "cursor_position", position = { 1, 0 } },
      { keys = "b", text = "Press b." }),
    task("mv-0", "movement", "Jump to the very start of the line with 0.",
      { "  hello" }, { 1, 6 },
      { type = "cursor_position", position = { 1, 0 } },
      { keys = "0", text = "Press 0." }),
    task("mv-$", "movement", "Jump to the last character of the line with $.",
      { "  hello" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 6 } },
      { keys = "$", text = "Press $." }),
    task("mv-3j", "movement", "Jump down three lines with 3j.",
      { "one", "two", "three", "four" }, { 1, 0 },
      { type = "cursor_position", position = { 4, 0 } },
      { keys = "3j", text = "Type 3, then j." }),
    task("mv-G", "movement", "Go to the last line with G.",
      { "one", "two", "three" }, { 2, 0 },
      { type = "cursor_position", position = { 3, 0 } },
      { keys = "G", text = "Press G." }),
  },
  insertion = {
    task("ins-i", "insertion", "Insert 'hello ' before the word: press i, type 'hello ', then <Esc>.",
      { "world" }, { 1, 0 },
      { type = "buffer", expected = { "hello world" } },
      { keys = "ihello <Esc>", text = "Press i, type 'hello ', press <Esc>." }),
    task("ins-a", "insertion", "The cursor is on the last character. Append ' world' with a.",
      { "hello" }, { 1, 5 },
      { type = "buffer", expected = { "hello world" } },
      { keys = "a world<Esc>", text = "Press a, type ' world', press <Esc>." }),
    task("ins-I", "insertion", "Insert 'yo ' at the first non-blank character with I.",
      { "  hi" }, { 1, 3 },
      { type = "buffer", expected = { "  yo hi" } },
      { keys = "Iyo <Esc>", text = "Press I, type 'yo ', press <Esc>." }),
    task("ins-o", "insertion", "The cursor is on 'top'. Open a new line below with o and type 'mid'.",
      { "top", "bottom" }, { 1, 0 },
      { type = "buffer", expected = { "top", "mid", "bottom" } },
      { keys = "omid<Esc>", text = "Press o, type 'mid', press <Esc>." }),
    task("ins-O", "insertion", "Open a new line above with O and type 'mid'.",
      { "top", "bottom" }, { 1, 0 },
      { type = "buffer", expected = { "mid", "top", "bottom" } },
      { keys = "Omid<Esc>", text = "Press O, type 'mid', press <Esc>." }),
    task("ins-s", "insertion", "The word is misspelled. Press s on the 's' and type 'p'.",
      { "foshur" }, { 1, 2 },
      { type = "buffer", expected = { "fophur" } },
      { keys = "sp", text = "Press s, then p." }),
    task("ins-r", "insertion", "Use r to replace the character under the cursor with 'o'.",
      { "x" }, { 1, 0 },
      { type = "buffer", expected = { "o" } },
      { keys = "ro", text = "Press r, then o." }),
    task("ins-S", "insertion", "Replace the whole line: press S, type 'clean', then <Esc>.",
      { "junk", "keep" }, { 1, 0 },
      { type = "buffer", expected = { "clean", "keep" } },
      { keys = "Sclean<Esc>", text = "Press S, type 'clean', press <Esc>." }),
  },
  editing = {
    task("ed-dw", "editing", "Delete the first word with dw.",
      { "remove this text" }, { 1, 0 },
      { type = "buffer", expected = { "this text" } },
      { keys = "dw", text = "Type dw." }),
    task("ed-D", "editing", "Delete from the cursor to the end of the line with D.",
      { "keep the rest" }, { 1, 4 },
      { type = "buffer", expected = { "keep" } },
      { keys = "D", text = "Press D." }),
    task("ed-cw", "editing", "Change the first word with cw: type 'goodbye', then <Esc>.",
      { "hello world" }, { 1, 0 },
      { type = "buffer", expected = { "goodbye world" } },
      { keys = "cwgoodbye<Esc>", text = "Type cw, type 'goodbye', press <Esc>." }),
    task("ed-dd", "editing", "Delete the line under the cursor with dd.",
      { "one", "two", "three" }, { 2, 0 },
      { type = "buffer", expected = { "one", "three" } },
      { keys = "dd", text = "Type dd." }),
    task("ed-yyp", "editing", "Duplicate the line: yank it with yy and paste it with p.",
      { "one" }, { 1, 0 },
      { type = "buffer", expected = { "one", "one" } },
      { keys = "yyp", text = "Type yy, then p." }),
    task("ed-u", "editing", "Delete two characters with 2x, then restore the line with u.",
      { "original" }, { 1, 0 },
      { type = "buffer", expected = { "original" } },
      { keys = "2xu", text = "Type 2x, then u." }, true),
    task("ed-~", "editing", "Toggle the case of the character under the cursor with ~.",
      { "hello" }, { 1, 0 },
      { type = "buffer", expected = { "Hello" } },
      { keys = "~", text = "Press ~." }),
    task("ed-x", "editing", "Delete the character under the cursor with x.",
      { "ab" }, { 1, 0 },
      { type = "buffer", expected = { "b" } },
      { keys = "x", text = "Press x." }),
  },
  ["text-objects"] = {
    task("to-diw", "text-objects", "Delete the word under the cursor with diw.",
      { "keep the dog" }, { 1, 9 },
      { type = "buffer", expected = { "keep the" } },
      { keys = "diw", text = "Type diw." }),
    task("to-daw", "text-objects", "Delete the word under the cursor AND its following space with daw.",
      { "dog in the yard" }, { 1, 4 },
      { type = "buffer", expected = { "dog the yard" } },
      { keys = "daw", text = "Type daw." }),
    task("to-ci(", "text-objects", "Change what is inside the parentheses: type ci(, then 'vim', then <Esc>.",
      { "hello (world)" }, { 1, 6 },
      { type = "buffer", expected = { "hello (vim)" } },
      { keys = "ci(vim<Esc>", text = "Type ci(, type 'vim', press <Esc>." }),
    task("to-da\"", "text-objects", "Delete the quoted text and its quotes with da\".",
      { 'say "hi"', "next" }, { 1, 5 },
      { type = "buffer", expected = { "say", "next" } },
      { keys = 'da"', text = "Type d, a, and the double quote." }),
    task("to-di'", "text-objects", "Delete the word inside the single quotes with di'.",
      { "the 'end'" }, { 1, 4 },
      { type = "buffer", expected = { "the ''" } },
      { keys = "di'", text = "Type d, i, and the single quote." }),
    task("to-ciw", "text-objects", "Change the word under the cursor: type ciw, then 'qux', then <Esc>.",
      { "foo bar baz" }, { 1, 4 },
      { type = "buffer", expected = { "foo qux baz" } },
      { keys = "ciwqux<Esc>", text = "Type ciw, type 'qux', press <Esc>." }),
    task("to-dip", "text-objects", "Delete the paragraph under the cursor with dip.",
      { "first para", "", "second para" }, { 1, 0 },
      { type = "buffer", expected = { "", "second para" } },
      { keys = "dip", text = "Type dip." }),
    task("to-viw", "text-objects", "Select the word under the cursor with viw. Stay in VISUAL mode.",
      { "select me now" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 1, 5 } },
      { keys = "viw", text = "Type viw." }),
  },
  visual = {
    task("vis-vll", "visual", "Select exactly three characters: press v, then l twice.",
      { "abcdef" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 1, 2 } },
      { keys = "vll", text = "Press v, then l twice." }),
    task("vis-V", "visual", "Select the whole line under the cursor with V.",
      { "alpha", "beta" }, { 2, 0 },
      { type = "selection", start = { 2, 0 }, finish = { 2, 3 } },
      { keys = "V", text = "Press V." }),
    task("vis-Cv", "visual", "Select a 2x2 block: press <C-v>, then l, then j.",
      { "ab", "cd" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 2, 1 } },
      { keys = "<C-v>lj", text = "Press <C-v>, l, j." }),
    task("vis-vld", "visual", "Select the word 'junk' with v and three l's, then delete it with d.",
      { "keep junk" }, { 1, 5 },
      { type = "buffer", expected = { "keep" } },
      { keys = "vllld", text = "Type vlll, then d." }),
    task("vis-Vd", "visual", "Select the line under the cursor with V and delete it with d.",
      { "one", "two", "three" }, { 2, 0 },
      { type = "buffer", expected = { "one", "three" } },
      { keys = "Vd", text = "Type V, then d." }),
    task("vis-viwU", "visual", "Select the word under the cursor with viw and uppercase it with U.",
      { "make this loud" }, { 1, 5 },
      { type = "buffer", expected = { "make THIS loud" } },
      { keys = "viwU", text = "Type viw, then U." }),
    task("vis-lll-y-p", "visual", "Select 'copy' with v and three l's, yank with y, go to the empty line below with j, and paste with p.",
      { "copy", "" }, { 1, 0 },
      { type = "buffer", expected = { "copy", "copy" } },
      { keys = "vlllyjp", text = "Type vlll, y, j, p." }),
    task("vis-vllllc", "visual", "Select 'cats' with v and four l's, change it with c: type 'dogs', then <Esc>.",
      { "I like cats" }, { 1, 7 },
      { type = "buffer", expected = { "I like dogs" } },
      { keys = "vllllcdogs<Esc>", text = "Type vllllc, type 'dogs', press <Esc>." }),
  },
}

-- Validate the entire pool at load time so a broken task can never reach a
-- learner.
for _, category in ipairs(M.CATEGORIES) do
  lesson_mod.validate({
    id = "pool-" .. category,
    title = category,
    exercises = TASKS[category],
  })
end

function M.all_tasks(category)
  return TASKS[category] or {}
end

function M.category_names()
  return M.CATEGORIES
end

function M.next_task(category, exclude_id)
  if M._pick then
    return M._pick(category, exclude_id)
  end
  local pool = TASKS[category]
  local candidates = {}
  for _, t in ipairs(pool) do
    if t.id ~= exclude_id then
      candidates[#candidates + 1] = t
    end
  end
  if #candidates == 0 then
    candidates = pool
  end
  return candidates[math.random(#candidates)]
end

-- Starts a practice session. opts: { category, mode, goal, limit_ms }.
function M.start(opts)
  opts = opts or {}
  local category = opts.category or M.CATEGORIES[1]
  local mode = opts.mode or "goal"
  local valid_cat, valid_mode = false, false
  for _, c in ipairs(M.CATEGORIES) do
    if c == category then valid_cat = true end
  end
  for _, m in ipairs(M.MODES) do
    if m == mode then valid_mode = true end
  end
  if not valid_cat or not valid_mode then
    vim.notify("vimforge: unknown practice category/mode", vim.log.levels.ERROR)
    return
  end

  local state = require("vimforge.state").active
  local runner = require("vimforge.runner")
  runner._begin_session({
    id = "practice-" .. category,
    title = "Practice: " .. category,
    concept = "",
    exercises = {},
  })

  state.practice = {
    category = category,
    mode = mode,
    goal = opts.goal or M.GOAL_DEFAULT,
    limit_ms = (mode == "time") and (opts.limit_ms or M.TIME_LIMIT_MS) or nil,
    done = 0,
    started_ms = vim.uv.now(),
    timer = nil,
  }
  if mode == "time" then
    local p = state.practice
    p.timer = vim.uv.new_timer()
    p.timer:start(p.limit_ms, 0, function()
      p.timer:stop()
      p.timer:close()
      p.timer = nil
      vim.schedule(function()
        if state.practice == p then
          M.finish("Time's up.")
        end
      end)
    end)
  end
  M.advance()
end

-- Advances to the next task, or ends the session when the goal is reached.
function M.advance()
  local state = require("vimforge.state").active
  local p = state.practice
  if not p then
    return
  end
  if p.mode == "goal" and p.done >= p.goal then
    M.finish(string.format("Goal reached: %d tasks.", p.done))
    return
  end
  local task = M.next_task(p.category, state.exercise and state.exercise.id)
  state.lesson = {
    id = "practice-" .. p.category,
    title = "Practice: " .. p.category,
    concept = "",
    exercises = { task },
  }
  state.lesson_id = state.lesson.id
  require("vimforge.runner").start_exercise(task)
end

-- Records a completed task (called by the runner on success).
function M.record_done(active)
  local p = active.practice
  if not p then
    return
  end
  local ms = active.task_started and (vim.uv.now() - active.task_started) or 0
  require("vimforge.progress").record_practice(p.category, ms)
  p.done = p.done + 1
end

-- Stops the session timer and clears the practice state.
function M.cleanup()
  local state = require("vimforge.state").active
  local p = state.practice
  if p and p.timer then
    p.timer:stop()
    p.timer:close()
    p.timer = nil
  end
  state.practice = nil
end

-- Ends the session: stops the timer, restores the learner's window, and
-- notifies with a short summary.
function M.finish(reason)
  local state = require("vimforge.state").active
  local p = state.practice
  if not p then
    return
  end
  local category, done = p.category, p.done
  M.cleanup()
  local runner = require("vimforge.runner")
  runner._quit_cleanup()
  local lines = { reason }
  local c = require("vimforge.progress").practice_stats()[category]
  if c and c.completed > 0 then
    lines[#lines + 1] = string.format(
      "%s: %d done   avg %.1fs   best %.1fs",
      category, c.completed, (c.total_ms / c.completed) / 1000, (c.best_ms or 0) / 1000)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "VimForge Practice" })
end

-- Chooser float: one row per category/mode combination.
function M.choose()
  local ui = require("vimforge.ui")
  local state = require("vimforge.state").active

  if state.selector_win and vim.api.nvim_win_is_valid(state.selector_win) then
    vim.api.nvim_win_close(state.selector_win, true)
    state.selector_win = nil
    state.selector_buf = nil
  end

  local combos = {}
  for _, cat in ipairs(M.CATEGORIES) do
    for _, mode in ipairs(M.MODES) do
      combos[#combos + 1] = { category = cat, mode = mode }
    end
  end

  local selected = 1
  local function label(c)
    local desc
    if c.mode == "goal" then
      desc = M.GOAL_DEFAULT .. " tasks"
    elseif c.mode == "time" then
      desc = math.floor(M.TIME_LIMIT_MS / 1000) .. " seconds"
    else
      desc = "until you quit"
    end
    return string.format("  %s / %s — %s", c.category, c.mode, desc)
  end

  local function build_rows()
    local rows = { { text = "  P R A C T I C E", hl = "VimForgeTitle" } }
    for i, c in ipairs(combos) do
      rows[#rows + 1] = {
        text = ((i == selected) and "▶ " or "  ") .. label(c),
        hl = (i == selected) and "VimForgeSelected" or "VimForgeInstruction",
      }
    end
    rows[#rows + 1] = { text = "  j/k move    <Enter> start    q close", hl = "VimForgeDim" }
    return rows
  end

  local win, buf = ui.show_selector(build_rows())
  state.selector_win = win
  state.selector_buf = buf

  local function redraw()
    if vim.api.nvim_buf_is_valid(buf) then
      ui.render_buffer(buf, build_rows())
    end
  end
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    state.selector_win = nil
    state.selector_buf = nil
  end

  vim.keymap.set("n", "j", function()
    selected = math.min(#combos, selected + 1)
    redraw()
  end, { buffer = buf })
  vim.keymap.set("n", "k", function()
    selected = math.max(1, selected - 1)
    redraw()
  end, { buffer = buf })
  vim.keymap.set("n", "<CR>", function()
    local c = combos[selected]
    close()
    M.start(c)
  end, { buffer = buf })
  vim.keymap.set("n", "q", close, { buffer = buf })
end

return M
