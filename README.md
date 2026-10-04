# vimforge

Learn Vim by using real Vim. A local-first, interactive Neovim plugin: pick a
lesson, practice in a scratch buffer that is real Vim, and get validated
feedback the moment you do the right thing.

No accounts, no network, no videos. Your buffer, your keys, checked by
Neovim itself.

## How it works

`:VimForge` opens a lesson selector. Each lesson is a short sequence of
exercises. For every exercise the plugin:

1. Opens a **scratch buffer** (or a real temp file for undo exercises) with
   the exercise's starting content and cursor position.
2. Shows an instruction panel in a right split (concept, instruction, hint
   and success messages).
3. Watches events (cursor moves, text changes, mode changes, yanks, Ex
   commands) and runs a debounced validation check.
4. On success: records progress, shows the success message, and advances on
   `<Enter>`.

You practice with real Vim semantics — operators, text objects, registers
and undo all behave exactly as they would in your own files. Lessons and
practice tasks use realistic content from daily backend work: Go, Python,
Ruby, JS/TS, Postgres SQL, Dockerfiles, k8s/compose YAML, shell, Makefile
and Markdown.

In an exercise: `F1` shows a hint, `q` quits the lesson (your buffer and
window are restored), `<Enter>` advances after success (also while in
VISUAL mode).

## Curriculum

| # | Lesson id          | Title                 | Focus |
|---|--------------------|-----------------------|-------|
| 1 | `intro-to-modes`   | Introduction to Modes | i, a, o, Esc |
| 2 | `moving-around`    | Moving Around         | h j k l, 0 $, gg G, counts |
| 3 | `word-motions`     | Word Motions          | w b e, W B, f t ; |
| 4 | `operators`        | Operators             | d c y, dd d$ D, cw C, yy p, ~, u |
| 5 | `text-objects`     | Text Objects          | di" da" ci( diw ci' dip, viw |
| 6 | `visual-mode`      | Visual Mode           | v V <C-v>, extend, d c U on selections |
| 7 | `searching`        | Searching             | /pattern, ?pattern, n, N |
| 8 | `ex-commands`      | Ex Commands           | :w, :q, :wq, :s |
| 9 | `insert-advanced`  | Inserting Like a Pro  | I, A, O, s, r, S |
| 10 | `copy-paste`       | Copy and Paste        | yy p, P, yw, named registers, cut |
| 11 | `dot-repeat`       | The Dot Command       | ., 2. / 3., repeat insertions |
| 12 | `marks-jumps`      | Marks and Jumps       | ma / `a, <C-o>, <C-i> |
| 13 | `quick-search`     | Quick Word Search     | *, #, n / N on words |
| 14 | `brackets`         | Text Objects: Brackets | di{ da{ ci{ ca{, di[ |
| 15 | `change-case`      | Change Case           | guw, gUw, gU$, gug$, gui( |
| 16 | `substitute-advanced` | Substitution and :g | :s///g, :%s, :2s, :g/pat/d |

## Practice

`P` in the selector (or `:VimForgePractice`) drills random tasks from a
skill pool — 48 tasks across five categories: movement, insertion,
editing, text objects, and visual. Pick a category and a mode:

- **goal** — complete 10 tasks
- **time** — as many as you can in 60 seconds
- **endless** — until you quit with `q`

Tasks flow back to back with auto-advance (no `<Enter>`), the panel shows
your task number, goal progress or time left, and `:VimForgeStats` shows
per-category done / average / best times alongside lesson completion.
Everything is local and free — there is no paywall to unlock.

## Requirements

- Neovim 0.10+ (uses `vim.keymap`, `nvim_create_autocmd`, `nvim_buf_set_lines`, ...)

No runtime dependencies. `plenary.nvim` is needed only for the test suite.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "tikarammardi/vimforge",
  config = true, -- or: opts = { auto_start = true }
}
```

Or with a plain runtimepath:

```sh
git clone https://github.com/tikarammardi/vimforge ~/.local/share/nvim/site/pack/plugins/start/vimforge
```

Then run `:VimForge` (or `:VimForgeStart <lesson-id>`).

## Commands

| Command                          | Description |
|----------------------------------|-------------|
| `:VimForge`                      | Open the lesson selector (includes a Practice entry) |
| `:VimForgeStart [id]`            | Start a lesson by id (default: first incomplete) |
| `:VimForgeNext`                  | Advance to the next exercise |
| `:VimForgeRestart`               | Restart the current exercise |
| `:VimForgePractice [cat] [mode]` | Start practice (chooser if no args; `cat` = movement/insertion/editing/text-objects/visual, `mode` = goal/time/endless) |
| `:VimForgeStats`                 | Lesson completion + practice stats float |
| `:VimForgeProgress`              | Show progress per lesson + overall % |
| `:VimForgeReset`                 | Clear all saved progress |

## Configuration

Works out of the box; all options have defaults:

```lua
require("vimforge").setup({
  check_delay = 120,       -- ms of quiet before a validation check runs
  panel_width = 34,        -- instruction panel width (columns)
  persist_progress = true, -- write progress.json
  auto_start = false,      -- open the selector on VimEnter
  data_dir = nil,          -- default: stdpath("data") .. "/vimforge"
})
```

Progress is stored as plain JSON at `<data_dir>/progress.json`
(default `~/.local/share/nvim/vimforge/progress.json` on Linux/macOS),
tracking completed lessons/exercises with attempt and hint counts, plus
per-category practice stats (completed tasks, total/best time).

## Writing lessons

A lesson is a declarative Lua table (`lua/vimforge/lessons/*.lua`,
registered in `lua/vimforge/lessons/init.lua`):

```lua
return {
  id = "my-lesson",
  title = "My Lesson",
  summary = "One line shown in the selector.",
  concept = "Explainer shown in the panel.",
  exercises = {
    {
      id = "my-exercise",
      instruction = "Do the thing.",
      initial_content = { "hello" },
      cursor = { 1, 0 },           -- {row, col}
      start_mode = "normal",       -- or "insert"
      show_target = true,          -- put a target extmark at the cursor_position
      validation = { type = "buffer", expected = { "HELLO" } },
      success_message = "ggGvU uppercases the file.",
      hints = { "Try a visual-line selection." },
      solution = { keys = "ggGvU", text = "gg, G, v, U." },
      file = false,                -- true: real temp file (undo origin)
    },
  },
}
```

Validator types:

| type              | checks |
|-------------------|--------|
| `buffer`          | full buffer content (trailing whitespace ignored) |
| `cursor_position` | cursor exactly at `{row, col}` |
| `mode`            | current mode name (`"normal"`, `"insert"`, `"visual"`, ...) |
| `selection`       | live visual selection spans `start`..`finish` |
| `register`        | register contents (default unnamed `"`) |
| `search`          | last search pattern (`/`) |
| `command`         | Ex commands entered (with common aliases, e.g. `w` matches `:wq`) |
| `file`            | temp file on disk (file-backed exercises) |
| `sequence`        | one of the allowed key sequences was pressed, in order |
| `composite`       | all sub-validations pass |

Every exercise must carry a canonical `solution.keys`; the test suite
replays every solution through the real engine via `feedkeys` and asserts
the validator passes — so each lesson is verified against actual Neovim
semantics.

## Development

```sh
make test              # full plenary suite (needs plenary.nvim; PLENARY=/path to override)
make test-one FILE=tests/spec/04_runner_spec.lua
make play              # open the plugin in a clean nvim: nvim --clean -u tests/minimal_init.lua -c VimForge
```

Layout:

```
plugin/vimforge.lua        command definitions (lazy: no startup cost)
lua/vimforge/
  init.lua                 public API
  config.lua               options
  state.lua                in-memory session state
  lesson.lua               lesson/exercise schema validation
  validator.lua            pure validation functions over a state snapshot
  progress.lua             durable progress (JSON)
  runner.lua               exercise state machine, events, panel wiring
  practice.lua             practice skill pool + session modes
  stats.lua                stats float
  ui.lua                   panel, selector, highlights, extmarks
  commands.lua             :VimForge* user commands
  lessons/                 the curriculum (one module per lesson)
tests/spec/                plenary.busted specs, incl. solution replay
```

## License

MIT
