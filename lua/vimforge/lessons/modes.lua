return {
  id = "intro-to-modes",
  title = "Introduction to Modes",
  summary = "Vim is modal: NORMAL mode for moving and commanding, INSERT mode for typing.",
  concept = "Vim is modal. In NORMAL mode you move around and issue commands; in INSERT mode you type text. Press <Esc> to return to NORMAL mode from anywhere.",
  exercises = {
    {
      id = "type-with-i",
      instruction = "Enter INSERT mode, type exactly: Hello Neovim! — then press <Esc> to return to NORMAL mode.",
      initial_content = { "" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "buffer", expected = { "Hello Neovim!" } },
          { type = "mode", expected = "normal" },
        },
      },
      success_message = "You typed in INSERT mode and returned to NORMAL mode.",
      hints = {
        "Press i to enter INSERT mode at the cursor.",
        "After typing, press <Esc> to get back to NORMAL mode.",
      },
      solution = { keys = "iHello Neovim!<Esc>", text = "Press i, type Hello Neovim!, then press <Esc>." },
    },
    {
      id = "append-with-A",
      instruction = "Append to the end of the line so it reads: Vim is modal. (A jumps to the end of the line and enters INSERT mode.)",
      initial_content = { "Vim" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { "Vim is modal." } },
      success_message = "A appended at the very end of the line.",
      hints = {
        "Press A to jump to the end of the line and start typing.",
        "Type ' is modal.' then press <Esc>.",
      },
      solution = { keys = "A is modal.<Esc>", text = "Press A, type ' is modal.', then <Esc>." },
    },
    {
      id = "new-line-with-o",
      instruction = "Press o to open a new line below the cursor, then type: Vim is modal.",
      initial_content = { "Hello Neovim!" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { "Hello Neovim!", "Vim is modal." } },
      success_message = "o opened a new line below and entered INSERT mode.",
      hints = {
        "Press o to create a new line below the current one.",
        "Type 'Vim is modal.' then press <Esc>.",
      },
      solution = { keys = "oVim is modal.<Esc>", text = "Press o, type Vim is modal., then <Esc>." },
    },
    {
      id = "complete-with-A",
      instruction = "Complete the sentence so it reads: The sky is blue. Append ' blue.' at the end of the line.",
      initial_content = { "The sky is" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { "The sky is blue." } },
      success_message = "The sentence is complete.",
      hints = {
        "Press A to go to the end of the line and start typing.",
        "Type ' blue.' then press <Esc>.",
      },
      solution = { keys = "A blue.<Esc>", text = "Press A, type ' blue.', then <Esc>." },
    },
    {
      id = "escape-to-normal",
      instruction = "You are in INSERT mode. Press <Esc> to return to NORMAL mode without changing the text.",
      initial_content = { "I love Vim" },
      cursor = { 1, 0 },
      start_mode = "insert",
      validation = {
        type = "composite",
        validations = {
          { type = "mode", expected = "normal" },
          { type = "buffer", expected = { "I love Vim" } },
        },
      },
      success_message = "<Esc> returned you to NORMAL mode.",
      hints = {
        "Press the <Esc> key.",
        "Make sure the text stays exactly 'I love Vim'.",
      },
      solution = { keys = "<Esc>", text = "Press <Esc>." },
    },
    {
      id = "insert-after-a",
      instruction = "This word should read 'dog'. The cursor is on the 'd'. Press a to insert right after the cursor, type 'o', then press <Esc>.",
      initial_content = { "dg" },
      cursor = { 1, 0 },
      validation = { type = "buffer", expected = { "dog" } },
      success_message = "a inserted text right after the cursor.",
      hints = {
        "Press a to start inserting after the cursor.",
        "Type 'o' then press <Esc>.",
      },
      solution = { keys = "ao<Esc>", text = "Press a, type o, then <Esc>." },
    },
  },
}
