return {
  "fedepujol/move.nvim",
  keys = {
    -- Normal Mode
    { "<S-A-j>", ":MoveLine(1)<CR>", desc = "Move Line Up" },
    { "<S-A-k>", ":MoveLine(-1)<CR>", desc = "Move Line Down" },
    { "<S-A-h>", ":MoveHChar(-1)<CR>", desc = "Move Character Left" },
    { "<S-A-l>", ":MoveHChar(1)<CR>", desc = "Move Character Right" },
    -- { "<leader>wf", ":MoveWord(-1)<CR>", mode = { "n" }, desc = "Move Word Left" },
    -- { "<leader>wb", ":MoveWord(1)<CR>", mode = { "n" }, desc = "Move Word Right" },
    -- Visual Mode
    { "<S-A-j>", ":MoveBlock(1)<CR>", mode = { "v" }, desc = "Move Block Up" },
    { "<S-A-k>", ":MoveBlock(-1)<CR>", mode = { "v" }, desc = "Move Block Down" },
    { "<S-A-h>", ":MoveHBlock(-1)<CR>", mode = { "v" }, desc = "Move Block Left" },
    { "<S-A-l>", ":MoveHBlock(1)<CR>", mode = { "v" }, desc = "Move Block Right" },
  },
  opts = {
    -- Config here
  },
}
