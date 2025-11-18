return {
  {
    "rcarriga/nvim-notify",
    config = function()
      local notify = require("notify")
      notify.setup({
        stages = "fade_in_slide_out",
        render = "compact",
        background_colour = "#1a1b26",
        timeout = 3000,
      })
      vim.notify = notify
    end,
  },

  -- Noice (para interceptar mensajes de Neovim)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      presets = {
        bottom_search = true, -- búsqueda abajo
        command_palette = true, -- cmdline en estilo paleta
        long_message_to_split = true, -- mensajes largos a split
        lsp_doc_border = true, -- borde en docs de LSP
      },
    },
  },
}
