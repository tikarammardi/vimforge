return {
  id = "substitute-advanced",
  title = "Substitution and :g",
  summary = ":s///g replaces every match on the line; :%s the file; :g runs a command on matching lines.",
  concept = "Plain :s replaces the first match on the line. The g flag replaces every match on the line; % targets every line (:%s). :g/{pattern}/{command} runs that command on each line matching the pattern — :g/TODO/d deletes every TODO line in one keystroke.",
  exercises = {
    {
      id = "replace-all-on-line-with-g",
      instruction = "Replace EVERY 'cat' on the line with 'dog': type :s/cat/dog/g and press <Enter>.",
      initial_content = { "cat cat cat" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "dog dog dog" } },
        },
      },
      success_message = "The g flag makes :s replace every match on the line.",
      hints = {
        "Type :s/cat/dog/g — note the trailing g before the final /.",
        "Without g, only the first 'cat' would change.",
      },
      solution = { keys = ":s/cat/dog/g\r", text = "Type :s/cat/dog/g, press <Enter>." },
    },
    {
      id = "replace-everywhere-with-percent",
      instruction = "Replace every 'cat' in the whole file: type :%s/cat/dog/ and press <Enter>. (Watch what happens to 'cats'.)",
      initial_content = { "one cat", "two cats" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "one dog", "two dogs" } },
        },
      },
      success_message = "% before s targets every line; :%s is the whole-file replace.",
      hints = {
        "Type :%s/cat/dog/ — the % replaces the line range.",
        "s matches a substring, so 'cats' becomes 'dogs'.",
      },
      solution = { keys = ":%s/cat/dog/\r", text = "Type :%s/cat/dog/, press <Enter>." },
    },
    {
      id = "replace-on-one-line-with-range",
      instruction = "Replace 'cat' with 'dog' on line 2 ONLY: type :2s/cat/dog/ and press <Enter>.",
      initial_content = { "cat cat", "cat" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "cat cat", "dog" } },
        },
      },
      success_message = "A line number before s limits the substitution to that line.",
      hints = {
        "Type :2s/cat/dog/ — the 2 is the line range.",
        "Line 1 keeps its 'cat cat'.",
      },
      solution = { keys = ":2s/cat/dog/\r", text = "Type :2s/cat/dog/, press <Enter>." },
    },
    {
      id = "delete-lines-matching-with-g",
      instruction = "Delete every line containing 'delete' in one command: type :g/delete/d and press <Enter>.",
      initial_content = { "keep me", "delete me", "keep me too" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "g" } },
          { type = "buffer", expected = { "keep me", "keep me too" } },
        },
      },
      success_message = ":g/{pattern}/{command} runs the command on each matching line.",
      hints = {
        "Type :g/delete/d — g for global, delete the matching lines.",
        "The d at the end is the command :g runs on each match.",
      },
      solution = { keys = ":g/delete/d\r", text = "Type :g/delete/d, press <Enter>." },
    },
  },
}
