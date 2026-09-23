return {
  id = "searching",
  title = "Searching",
  summary = "/pattern searches forward, ? backward; n and N jump between matches.",
  concept = "Type / then a pattern and press <Enter> to search forward; ? searches backward. n repeats the search in the same direction, N in the opposite one. The matched text is highlighted, and the cursor lands on the match. / alone re-runs the previous search.",
  exercises = {
    {
      id = "search-forward-with-slash",
      instruction = "Search for the word 'world' with / and press <Enter>. The cursor must land on the 'w' of 'world'.",
      initial_content = { "hello there world" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "world" },
          { type = "cursor_position", position = { 1, 12 } },
        },
      },
      success_message = "/pattern searches forward from the cursor.",
      hints = {
        "Type /world, then <Enter>.",
        "The cursor jumps to the first match after the cursor.",
      },
      solution = { keys = "/world\r", text = "Type /world, press <Enter>." },
    },
    {
      id = "next-match-with-n",
      instruction = "Search for 'cat', then jump to the SECOND occurrence of 'cat' with n.",
      initial_content = { "a cat b cat c cat" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 8 } },
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
      initial_content = { "one cat two cat three" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 4 } },
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
      instruction = "Search BACKWARD for 'cat' with ? and <Enter>. The cursor must land on the last 'cat' in the line.",
      initial_content = { "cat and cat" },
      cursor = { 1, 0 },
      validation = {
        type = "composite",
        validations = {
          { type = "search", pattern = "cat" },
          { type = "cursor_position", position = { 1, 8 } },
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
