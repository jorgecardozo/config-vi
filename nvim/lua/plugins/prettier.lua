return {
  "stevearc/conform.nvim",
  opts = {
    -- Asociamos Prettier a los lenguajes que quieras
    formatters_by_ft = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      markdown = { "prettier" },
    },

    -- Corre Prettier al guardar
    format_on_save = {
      lsp_fallback = true,
      timeout_ms = 500,
    },

    -- Config extra para usar el binario local de node_modules
    formatters = {
      prettier = {
        command = "prettier",
        -- Busca siempre el binario en ./node_modules primero
        cwd = require("conform.util").root_file({
          ".prettierrc",
          "prettier.config.js",
          "package.json",
        }),
      },
    },
  },
}
