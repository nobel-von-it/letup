return {
	"melancholy",
	dir = vim.fn.stdpath("config") .. "/themes/melancholy",
	lazy = false,
	priority = 1000,
	config = function()
		vim.cmd("colorscheme melancholy")
	end,
}
