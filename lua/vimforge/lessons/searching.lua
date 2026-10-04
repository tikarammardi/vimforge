return {
  id = "searching",
  title = "Searching",
  summary = "/pattern searches forward, ? backward; n and N jump between matches.",
  concept = "Type / then a pattern and press <Enter> to search forward; ? searches backward. n repeats the search in the same direction, N in the opposite one. The matched text is highlighted, and the cursor lands on the match. / alone re-runs the previous search. Searching is how you navigate large files: find a symbol, then n through every use.",
  exercises = {
    {
      id = "search-forward-with-slash",
      instruction = "Search for the function name 'handle' with / and press <Enter>. The cursor must land on the 'h' of 'handle'.",
      initial_content = { "func handle(ctx context.Context) error {" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "handle" },
          { type = "cursor_position", position = { 1, 5 } },
        },
      },
      success_message = "/pattern searches forward from the cursor.",
      hints = {
        "Type /handle, then <Enter>.",
        "The cursor jumps to the first match after the cursor.",
      },
      solution = { keys = "/handle\r", text = "Type /handle, press <Enter>." },
    },
    {
      id = "next-match-with-n",
      instruction = "The cursor is on the first 'cat'. Search with /cat (it skips the match at the cursor), then press n. The cursor must end on the last 'cat' in the line (the one before '> out').",
      initial_content = { "cat /var/log/app.log | cat -n | cat > out" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 32 } },
        },
      },
      success_message = "n repeats the last search in the same direction.",
      hints = {
        "Type /cat, <Enter>, then n.",
        "n goes to the next match, N to the previous one.",
      },
      solution = { keys = "/cat\rn", text = "Search /cat, then press n." },
    },
    {
      id = "previous-match-with-N",
      instruction = "Search for 'cat', jump to the second one with n, then back to the first one with N. The cursor must end on the first 'cat'.",
      initial_content = { "backup: cat a && cat b" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 8 } },
        },
      },
      success_message = "N repeats the last search in the opposite direction.",
      hints = {
        "Type /cat, <Enter>, then n, then N.",
        "N goes backwards to the previous match.",
      },
      solution = { keys = "/cat\rnN", text = "Search /cat, press n, then N." },
    },
    {
      id = "search-backward-with-question",
      instruction = "Search BACKWARD for 'cat' with ? and <Enter>. The cursor must land on the last 'cat' in the line (before '-n').",
      initial_content = { "cat hosts.conf | cat -n" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 17 } },
        },
      },
      success_message = "?pattern searches backward from the cursor.",
      hints = {
        "Type ?cat, then <Enter>.",
        "? is the backward twin of /.",
      },
      solution = { keys = "?cat\r", text = "Type ?cat, press <Enter>." },
    },
  },
}
