  -- URL: https://github.com/nvim-treesitter/nvim-treesitter-context
  --   -- Description: Muestra el contexto actual (función donde estás) en la parte superior
return       {
           "nvim-treesitter/nvim-treesitter-context",
               event = "VeryLazy",
                   opts = {
                         enable = true,
                               max_lines = 3, -- Máximo 3 líneas de contexto
                                     min_window_height = 0,
                                           line_numbers = true,
                                                 multiline_threshold = 20,
                                                       trim_scope = 'outer',
                                                             mode = 'cursor', -- Basado en posición del cursor
                                                                 },
                                                                     config = function(_, opts)
                                                                           require("treesitter-context").setup(opts)
                                                                               end,
                                                                                 }
