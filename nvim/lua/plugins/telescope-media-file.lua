return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      mappings = {
        ["P"] = "toggle_preview",
        ["o"] = function(state)
          local node = state.tree:get_node()
          print("Node type: " .. (node.type or "nill"))
          print("Node path: " .. (node:get_id() or "nill"))
          if node.type == "file" then
            local filepath = node:get_id()
            local ext = filepath:match("%.([^%.]+)$")

            -- Si es una imagen, abrirla con feh
            if ext and vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "svg", "webp" }, ext:lower()) then
              vim.fn.system("feh '" .. filepath .. "' 2>/dev/null &")
              print("Opening: " .. vim.fn.fnamemodify(filepath, ":t"))
            else
              print("Not an image file")
            end
          end
        end,
      },
    },
    preview = {
      enabled = true,
    },
  },
}
