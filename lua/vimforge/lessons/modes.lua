return {
  id = "intro-to-modes",
  title = "Introduction to Modes",
  summary = "Vim is modal: NORMAL mode for moving and commanding, INSERT mode for typing.",
  concept = "Vim is modal. In NORMAL mode you move around and issue commands; in INSERT mode you type text. Press <Esc> to return to NORMAL mode from anywhere. The exercises edit a small Go file — the same motions you will use in your own code.",
  exercises = {
    {
      id = "type-with-i",
      instruction = "Enter INSERT mode, type exactly: package main — then press <Esc> to return to NORMAL mode.",
      initial_content = { "" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "buffer", expected = { "package main" } },
          { type = "mode", expected = "normal" },
        },
      },
      success_message = "You typed in INSERT mode and returned to NORMAL mode.",
      hints = {
        "Press i to enter INSERT mode at the cursor.",
        "After typing, press <Esc> to get back to NORMAL mode.",
      },
      solution = { keys = "ipackage main<Esc>", text = "Press i, type 'package main', then press <Esc>." },
    },
    {
      id = "append-with-A",
      instruction = "The assignment is incomplete. Press A to jump to the end of the line, type ' \"api\"', then <Esc>, so the line reads: var name = \"api\"",
      initial_content = { "var name =" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { 'var name = "api"' } },
      success_message = "A appended at the very end of the line.",
      hints = {
        "Press A to jump to the end of the line and start typing.",
        "Type ' \"api\"' then press <Esc>.",
      },
      solution = { keys = 'A "api"<Esc>', text = "Press A, type ' \"api\"', then <Esc>." },
    },
    {
      id = "new-line-with-o",
      instruction = "Press o to open a new line below the cursor and type the log line: fmt.Println(port)",
      initial_content = { "var port = 8080" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { "var port = 8080", "fmt.Println(port)" } },
      success_message = "o opened a new line below and entered INSERT mode.",
      hints = {
        "Press o to create a new line below the current one.",
        "Type 'fmt.Println(port)' then press <Esc>.",
      },
      solution = { keys = "ofmt.Println(port)<Esc>", text = "Press o, type the log line, then press <Esc>." },
    },
    {
      id = "complete-with-A",
      instruction = "Finish the error return so the line reads: return errors.New(\"not found\") — append '\"not found\")' at the end.",
      initial_content = { "return errors.New(" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { 'return errors.New("not found")' } },
      success_message = "The statement is complete.",
      hints = {
        "Press A to go to the end of the line and start typing.",
        "Type '\"not found\")' then press <Esc>.",
      },
      solution = { keys = 'A"not found")<Esc>', text = "Press A, type '\"not found\")', then <Esc>." },
    },
    {
      id = "escape-to-normal",
      instruction = "You are in INSERT mode on a TODO comment. Press <Esc> to return to NORMAL mode without changing the text.",
      initial_content = { "// TODO: migrate to k8s" },
      cursor = { 1, 0 },
      start_mode = "insert",
      validation = {
        type = "composite",
        validations = {
          { type = "mode", expected = "normal" },
          { type = "buffer", expected = { "// TODO: migrate to k8s" } },
        },
      },
      success_message = "<Esc> returned you to NORMAL mode.",
      hints = {
        "Press the <Esc> key.",
        "Make sure the comment stays exactly as it was.",
      },
      solution = { keys = "<Esc>", text = "Press <Esc>." },
    },
    {
      id = "insert-after-a",
      instruction = "The variable is misspelled: 'contxt'. The cursor is on the 't' after 'con'. Press a to insert right after the cursor, type 'e', then <Esc>, so it reads: context",
      initial_content = { "contxt := context.Background()" },
      cursor = { 1, 3 },
      validation = { type = "buffer", expected = { "context := context.Background()" } },
      success_message = "a inserted text right after the cursor.",
      hints = {
        "Press a to start inserting after the cursor.",
        "Type 'e' then press <Esc>.",
      },
      solution = { keys = "ae<Esc>", text = "Press a, type e, then <Esc>." },
    },
  },
}
