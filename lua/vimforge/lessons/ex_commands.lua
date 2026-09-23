return {
  id = "ex-commands",
  title = "Ex Commands",
  summary = "Commands typed on the command line: :w saves, :q closes, :wq does both.",
  concept = "Press : to open the command line (Ex mode). :w (write) saves the buffer to the file on disk. :q (quit) closes the buffer — it only works if the file was saved or is unchanged. :wq saves and closes in one go. Most commands can be abbreviated: :w is :write, :q is :quit.",
  exercises = {
    {
      id = "save-file-with-:w",
      instruction = "Append ' 1.0' to the line, then save the file with :w so the file on disk reads: release 1.0",
      file = true,
      initial_content = { "release" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "w" } },
          { type = "file", expected = { "release 1.0" } },
        },
      },
      success_message = ":w writes the buffer to the file on disk.",
      hints = {
        "Press A, type ' 1.0', press <Esc>.",
        "Then type :w and press <Enter>.",
      },
      solution = { keys = "A 1.0<Esc>:w\r", text = "Append ' 1.0', then :w." },
    },
    {
      id = "close-buffer-with-:q",
      instruction = "The file is unchanged. Close the buffer with :q.",
      file = true,
      initial_content = { "hello world" },
      cursor = { 1, 0 },
      validation = { type = "command", expected = { "q" } },
      success_message = ":q closes the buffer (only if the file is saved).",
      hints = {
        "Type :q, then <Enter>.",
        ":q is short for :quit.",
      },
      solution = { keys = ":q\r", text = "Type :q, press <Enter>." },
    },
    {
      id = "save-and-close-with-:wq",
      instruction = "Append '!' to the line, then save and close the file in one command with :wq.",
      file = true,
      initial_content = { "final" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "wq" } },
          { type = "file", expected = { "final!" } },
        },
      },
      success_message = ":wq saves the file and closes the buffer.",
      hints = {
        "Press A, type '!', press <Esc>.",
        "Then type :wq and press <Enter>.",
      },
      solution = { keys = "A!<Esc>:wq\r", text = "Append '!', then :wq." },
    },
    {
      id = "substitute-with-:s",
      instruction = "Use :s to replace 'cat' with 'dog' on the line: type :s/cat/dog/ and press <Enter>.",
      initial_content = { "the cat sat" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "the dog sat" } },
        },
      },
      success_message = ":s/{find}/{replace}/ substitutes on the current line.",
      hints = {
        "Type :s/cat/dog/, then <Enter>.",
        "Add a trailing g to replace every occurrence: :s/cat/dog/g.",
      },
      solution = { keys = ":s/cat/dog/\r", text = "Type :s/cat/dog/, press <Enter>." },
    },
  },
}
