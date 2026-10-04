-- Practice: drill random tasks from a skill pool, vimforge style.
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
    task("mv-jj", "movement", "Move down exactly two lines with jj, to the 'SELECT version()' line.",
      { "SELECT 1;", "SELECT now();", "SELECT version();" }, { 1, 0 },
      { type = "cursor_position", position = { 3, 0 } },
      { keys = "jj", text = "Press j twice." }),
    task("mv-lllll", "movement", "Move right five characters with lllll (the cursor lands on the 'G' of 'Get').",
      { "http.Get(url)" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 5 } },
      { keys = "lllll", text = "Press l five times." }),
    task("mv-w", "movement", "Move to the start of the next word ('name') with w.",
      { "var name = \"api\"" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 4 } },
      { keys = "w", text = "Press w." }),
    task("mv-b", "movement", "The cursor is on the 'm' of 'name'. Move back to the start of 'name' with b.",
      { "var name = \"api\"" }, { 1, 6 },
      { type = "cursor_position", position = { 1, 4 } },
      { keys = "b", text = "Press b." }),
    task("mv-0", "movement", "Jump to the very start of the indented line with 0.",
      { "    if err != nil {" }, { 1, 18 },
      { type = "cursor_position", position = { 1, 0 } },
      { keys = "0", text = "Press 0." }),
    task("mv-$", "movement", "Jump to the last character of the line with $.",
      { "    if err != nil {" }, { 1, 0 },
      { type = "cursor_position", position = { 1, 18 } },
      { keys = "$", text = "Press $." }),
    task("mv-3j", "movement", "Jump down three lines with 3j, to the 'go test' line.",
      { "build:", "\tgo build -o bin/api .", "test:", "\tgo test ./..." }, { 1, 0 },
      { type = "cursor_position", position = { 4, 0 } },
      { keys = "3j", text = "Type 3, then j." }),
    task("mv-G", "movement", "Go to the last line of the Dockerfile with G.",
      { "FROM golang:1.22", "WORKDIR /src", 'CMD ["./api"]' }, { 1, 0 },
      { type = "cursor_position", position = { 3, 0 } },
      { keys = "G", text = "Press G." }),
    task("mv-star", "movement", "With the cursor on the first 'ctx', jump to the next one with *.",
      { "use(ctx, ctx)" }, { 1, 4 },
      { type = "cursor_position", position = { 1, 9 } },
      { keys = "*", text = "Press *." }),
    task("mv-hash", "movement", "With the cursor on the second 'ctx', jump to the previous one with #.",
      { "use(ctx, ctx)" }, { 1, 9 },
      { type = "cursor_position", position = { 1, 4 } },
      { keys = "#", text = "Press #." }),
  },
  insertion = {
    task("ins-i", "insertion", "The variable name is missing. The cursor is on the space where it belongs: press i, type 'count', then <Esc>.",
      { "const  = 42;" }, { 1, 6 },
      { type = "buffer", expected = { "const count = 42;" } },
      { keys = "icount<Esc>", text = "Press i, type 'count', press <Esc>." }),
    task("ins-a", "insertion", "The statement is missing its semicolon. The cursor is on the last digit: append ';' with a.",
      { "const count = 42" }, { 1, 15 },
      { type = "buffer", expected = { "const count = 42;" } },
      { keys = "a;<Esc>", text = "Press a, type ';', press <Esc>." }),
    task("ins-I", "insertion", "Add a YAML comment before the key: insert '# primary ' at the first non-blank character with I.",
      { "    port: 8080" }, { 1, 4 },
      { type = "buffer", expected = { "    # primary port: 8080" } },
      { keys = "I# primary <Esc>", text = "Press I, type '# primary ', press <Esc>." }),
    task("ins-o", "insertion", "The cursor is on the 'var port' line. Open a new line below with o and type the log line.",
      { "var port = 8080", "http.ListenAndServe(addr, nil)" }, { 1, 0 },
      { type = "buffer", expected = { "var port = 8080", "fmt.Println(addr)", "http.ListenAndServe(addr, nil)" } },
      { keys = "ofmt.Println(addr)<Esc>", text = "Press o, type the log line, press <Esc>." }),
    task("ins-O", "insertion", "The Dockerfile must install dependencies first. The cursor is on the CMD line: open a line above with O and type the COPY instruction.",
      { "COPY . .", 'CMD ["node", "server.js"]' }, { 2, 0 },
      { type = "buffer", expected = { "COPY . .", "COPY package.json ./", 'CMD ["node", "server.js"]' } },
      { keys = "OCOPY package.json ./<Esc>", text = "Press O, type the COPY line, press <Esc>." }),
    task("ins-s", "insertion", "The host is misspelled: 'localhont'. Press s on the 'n' and type 's'.",
      { 'const host = "localhont";' }, { 1, 21 },
      { type = "buffer", expected = { 'const host = "localhost";' } },
      { keys = "ss", text = "Press s, then s." }),
    task("ins-r", "insertion", "The Makefile port has a letter O instead of a zero. Use r to replace the character under the cursor with '0'.",
      { "PORT ?= 8O80" }, { 1, 9 },
      { type = "buffer", expected = { "PORT ?= 8080" } },
      { keys = "r0", text = "Press r, then 0." }),
    task("ins-S", "insertion", "The comment is stale. Replace the whole line: press S, type the new comment, then <Esc>.",
      { "# legacy: docker-compose only" }, { 1, 0 },
      { type = "buffer", expected = { "# now: k8s via k3s" } },
      { keys = "S# now: k8s via k3s<Esc>", text = "Press S, type the new comment, press <Esc>." }),
  },
  editing = {
    task("ed-dw", "editing", "Delete the first word ('const') with dw.",
      { "const junk = 1;" }, { 1, 0 },
      { type = "buffer", expected = { "junk = 1;" } },
      { keys = "dw", text = "Type dw." }),
    task("ed-D", "editing", "Drop the trailing comment: with the cursor on the '/', delete from the cursor to the end of the line with D.",
      { "port := 8080 // TODO: move to config" }, { 1, 13 },
      { type = "buffer", expected = { "port := 8080" } },
      { keys = "D", text = "Press D." }),
    task("ed-cw", "editing", "Rename the variable: change the first word with cw, type 'interval', then <Esc>.",
      { "delay := 100 * time.Millisecond" }, { 1, 0 },
      { type = "buffer", expected = { "interval := 100 * time.Millisecond" } },
      { keys = "cwinterval<Esc>", text = "Type cw, type 'interval', press <Esc>." }),
    task("ed-dd", "editing", "Delete the stale TODO comment line with dd.",
      { 'import "fmt"', "// TODO: remove debug import", 'import "log"' }, { 2, 0 },
      { type = "buffer", expected = { 'import "fmt"', 'import "log"' } },
      { keys = "dd", text = "Type dd." }),
    task("ed-yyp", "editing", "Duplicate the compose setting: yank the line with yy and paste it with p.",
      { "  retries: 3" }, { 1, 0 },
      { type = "buffer", expected = { "  retries: 3", "  retries: 3" } },
      { keys = "yyp", text = "Type yy, then p." }),
    task("ed-u", "editing", "Delete two characters with 2x, then restore the line with u.",
      { "port := 8080" }, { 1, 0 },
      { type = "buffer", expected = { "port := 8080" } },
      { keys = "2xu", text = "Type 2x, then u." }, true),
    task("ed-~", "editing", "The flag should be unexported. Toggle the case of the character under the cursor with ~.",
      { "IsDev := true" }, { 1, 0 },
      { type = "buffer", expected = { "isDev := true" } },
      { keys = "~", text = "Press ~." }),
    task("ed-x", "editing", "There is a stray semicolon. Delete the character under the cursor with x.",
      { "server.listen(3000);;" }, { 1, 20 },
      { type = "buffer", expected = { "server.listen(3000);" } },
      { keys = "x", text = "Press x." }),
    task("ed-guw", "editing", "The constant should be a plain variable. Lowercase the word under the cursor with guw.",
      { "MAX_ATTEMPTS = 5" }, { 1, 0 },
      { type = "buffer", expected = { "max_attempts = 5" } },
      { keys = "guw", text = "Type guw." }),
    task("ed-gU$", "editing", "Normalize the log line: uppercase from the cursor to the end of the line with gU$.",
      { "warn: disk full" }, { 1, 0 },
      { type = "buffer", expected = { "WARN: DISK FULL" } },
      { keys = "gU$", text = "Type gU$." }),
    task("ed-s-g", "editing", "Rename both string arguments on the line with :s/user/admin/g.",
      { 'db.Exec(ctx, "user", "user")' }, { 1, 0 },
      { type = "buffer", expected = { 'db.Exec(ctx, "admin", "admin")' } },
      { keys = ":s/user/admin/g\r", text = "Type :s/user/admin/g, press <Enter>." }),
    task("ed-g-del", "editing", "Delete the TODO comment line with :g/TODO/d.",
      { "db, err := gorm.Open(dsn, cfg)", "// TODO: close db on exit", "check(err)" }, { 1, 0 },
      { type = "buffer", expected = { "db, err := gorm.Open(dsn, cfg)", "check(err)" } },
      { keys = ":g/TODO/d\r", text = "Type :g/TODO/d, press <Enter>." }),
  },
  ["text-objects"] = {
    task("to-diw", "text-objects", "Delete the word under the cursor with diw.",
      { "return count" }, { 1, 7 },
      { type = "buffer", expected = { "return" } },
      { keys = "diw", text = "Type diw." }),
    task("to-daw", "text-objects", "Delete the word under the cursor AND its following space with daw.",
      { "echo starting" }, { 1, 5 },
      { type = "buffer", expected = { "echo" } },
      { keys = "daw", text = "Type daw." }),
    task("to-ci(", "text-objects", "Change what is inside the parentheses: type ci(, then 'fetch', then <Esc>.",
      { "retry(load)" }, { 1, 6 },
      { type = "buffer", expected = { "retry(fetch)" } },
      { keys = "ci(fetch<Esc>", text = "Type ci(, type 'fetch', press <Esc>." }),
    task("to-da\"", "text-objects", "Drop the whole string literal: delete the quoted text and its quotes with da\".",
      { 'label := "TODO: remove"' }, { 1, 0 },
      { type = "buffer", expected = { "label :=" } },
      { keys = 'da"', text = "Type d, a, and the double quote." }),
    task("to-di'", "text-objects", "Empty the Ruby string: delete the word inside the single quotes with di'.",
      { "mode = 'dev'" }, { 1, 8 },
      { type = "buffer", expected = { "mode = ''" } },
      { keys = "di'", text = "Type d, i, and the single quote." }),
    task("to-ciw", "text-objects", "Rename the first argument: change the word under the cursor with ciw, type 'page', then <Esc>.",
      { "render(view, data)" }, { 1, 7 },
      { type = "buffer", expected = { "render(page, data)" } },
      { keys = "ciwpage<Esc>", text = "Type ciw, type 'page', press <Esc>." }),
    task("to-dip", "text-objects", "Delete the curl paragraph in the README with dip.",
      { "# API", "", "curl -s localhost:8080/healthz" }, { 3, 0 },
      { type = "buffer", expected = { "# API" } },
      { keys = "dip", text = "Type dip." }),
    task("to-viw", "text-objects", "Select the identifier 'port' with viw. Stay in VISUAL mode.",
      { "var port = 8080" }, { 1, 4 },
      { type = "selection", start = { 1, 4 }, finish = { 1, 7 } },
      { keys = "viw", text = "Type viw." }),
    task("to-di{", "text-objects", "Clear the struct literal: delete the inside of the braces (keep them) with di{.",
      { "opts := Options{Verbose: true}" }, { 1, 15 },
      { type = "buffer", expected = { "opts := Options{}" } },
      { keys = "di{", text = "Type di{." }),
    task("to-ci{", "text-objects", "Bump the timeout: type ci{, then ' timeout: 5000 ' (keep the spaces), then <Esc>.",
      { "return { timeout: 3000 };" }, { 1, 7 },
      { type = "buffer", expected = { "return { timeout: 5000 };" } },
      { keys = "ci{ timeout: 5000 <Esc>", text = "Type ci{, type ' timeout: 5000 ', press <Esc>." }),
  },
  visual = {
    task("vis-vll", "visual", "Select exactly three characters: press v, then l twice.",
      { "var x = 1" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 1, 2 } },
      { keys = "vll", text = "Press v, then l twice." }),
    task("vis-V", "visual", "Select the whole line under the cursor with V.",
      { "port := 8080" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 1, 11 } },
      { keys = "V", text = "Press V." }),
    task("vis-Cv", "visual", "Select a 2x2 block: press <C-v>, then l, then j.",
      { "a = 1", "b = 2" }, { 1, 0 },
      { type = "selection", start = { 1, 0 }, finish = { 2, 1 } },
      { keys = "<C-v>lj", text = "Press <C-v>, l, j." }),
    task("vis-vld", "visual", "Select the word 'junk' with v and three l's, then delete it with d.",
      { "app.use(junk)" }, { 1, 8 },
      { type = "buffer", expected = { "app.use()" } },
      { keys = "vllld", text = "Type vlll, then d." }),
    task("vis-Vd", "visual", "Delete the unused import: select the line under the cursor with V and delete it with d.",
      { 'import "fmt"', 'import "os"', "main()" }, { 2, 0 },
      { type = "buffer", expected = { 'import "fmt"', "main()" } },
      { keys = "Vd", text = "Press V, then d." }),
    task("vis-viwU", "visual", "Select the word under the cursor with viw and uppercase it with U.",
      { 'log.Println("make this loud")' }, { 1, 18 },
      { type = "buffer", expected = { 'log.Println("make THIS loud")' } },
      { keys = "viwU", text = "Type viw, then U." }),
    task("vis-lll-y-p", "visual", "Select 'TOKEN' with v and four l's, yank with y, go to the empty line below with j, and paste with p.",
      { 'const TOKEN = "abc";', "" }, { 1, 6 },
      { type = "buffer", expected = { 'const TOKEN = "abc";', "TOKEN" } },
      { keys = "vllllyjp", text = "Type vllll, y, j, p." }),
    task("vis-vlllc", "visual", "Rename the route: select 'cats' with v and three l's, change it with c, type 'users', then <Esc>.",
      { "fetch('/cats');" }, { 1, 8 },
      { type = "buffer", expected = { "fetch('/users');" } },
      { keys = "vlllcusers<Esc>", text = "Type vlllc, type 'users', press <Esc>." }),
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
