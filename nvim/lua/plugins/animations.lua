return {
	"echasnovski/mini.nvim",
	version = false,
	config = function()
		require("mini.animate").setup({
			resize = {
				enable = false,
			},
			open= {
				enable = false,
			},
			close = {
				enable = false,
			},
			scroll = {
				enable = false,
			},
		})
	end
}
