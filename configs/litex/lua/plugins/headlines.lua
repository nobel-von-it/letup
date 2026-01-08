return {
	"lukas-reineke/headlines.nvim",
	dependencies = "nvim-treesitter/nvim-treesitter",
	opts = {
		markdown = {
			headline_highlights = { "Headline1", "Headline2", "Headline3" },
			codeblock_highlight = "CodeBlock",
			dash_highlight = "Dash",
			dash_string = "―",
			fat_headlines = true,
			spacing = 1,
		},
	},
}
