return {
  id = "substitute-advanced",
  title = "Substitution and :g",
  summary = ":s///g replaces every match on the line; :%s the file; :g runs a command on matching lines.",
  concept = "Plain :s replaces the first match on the line. The g flag replaces every match on the line; % targets every line (:%s) — the everyday rename. :g/{pattern}/{command} runs that command on each line matching the pattern — :g/TODO/d deletes every TODO line in one keystroke.",
  exercises = {
    {
      id = "replace-all-on-line-with-g",
      instruction = "Rename every use of 'user' on the line to 'admin': type :s/user/admin/g and press <Enter>.",
      initial_content = { "render(user, user.name, user)" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "render(admin, admin.name, admin)" } },
        },
      },
      success_message = "The g flag makes :s replace every match on the line.",
      hints = {
        "Type :s/user/admin/g — note the trailing g before the final /.",
        "Without g, only the first 'user' would change.",
      },
      solution = { keys = ":s/user/admin/g\r", text = "Type :s/user/admin/g, press <Enter>." },
    },
    {
      id = "replace-everywhere-with-percent",
      instruction = "Rename 'oldName' to 'newName' in the whole file: type :%s/oldName/newName/ and press <Enter>. (Watch what happens to 'oldNames'.)",
      initial_content = { 'oldName := "api"', "fmt.Println(oldNames)" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { 'newName := "api"', "fmt.Println(newNames)" } },
        },
      },
      success_message = "% before s targets every line; :%s is the whole-file replace.",
      hints = {
        "Type :%s/oldName/newName/ — the % replaces the line range.",
        "s matches a substring, so 'oldNames' becomes 'newNames'.",
      },
      solution = { keys = ":%s/oldName/newName/\r", text = "Type :%s/oldName/newName/, press <Enter>." },
    },
    {
      id = "replace-on-one-line-with-range",
      instruction = "Replace 'cat' with 'dog' on line 2 ONLY: type :2s/cat/dog/ and press <Enter>.",
      initial_content = { "cat: alpha", "cat: beta" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "s" } },
          { type = "buffer", expected = { "cat: alpha", "dog: beta" } },
        },
      },
      success_message = "A line number before s limits the substitution to that line.",
      hints = {
        "Type :2s/cat/dog/ — the 2 is the line range.",
        "Line 1 keeps its 'cat'.",
      },
      solution = { keys = ":2s/cat/dog/\r", text = "Type :2s/cat/dog/, press <Enter>." },
    },
    {
      id = "delete-lines-matching-with-g",
      instruction = "Delete the TODO comment line in one command: type :g/TODO/d and press <Enter>.",
      initial_content = {
        'conn, err := sql.Open("postgres", dsn)',
        "// TODO: add connection pool",
        "check(err)",
      },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "command", expected = { "g" } },
          { type = "buffer", expected = { 'conn, err := sql.Open("postgres", dsn)', "check(err)" } },
        },
      },
      success_message = ":g/{pattern}/{command} runs the command on each matching line.",
      hints = {
        "Type :g/TODO/d — g for global, delete the matching lines.",
        "The d at the end is the command :g runs on each match.",
      },
      solution = { keys = ":g/TODO/d\r", text = "Type :g/TODO/d, press <Enter>." },
    },
  },
}
