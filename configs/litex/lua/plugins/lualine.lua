return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			theme = "auto",
			component_separators = "",
			section_separators = "",
			globalstatus = true,
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { { "filename", path = 1 } },
			lualine_c = {
				-- Функция для подсчета слов (только для Markdown)
				function()
					if vim.bo.filetype == "markdown" or vim.bo.filetype == "text" then
						return "Слов: " .. tostring(vim.fn.wordcount().words)
					end
					return ""
				end,
			},
			lualine_x = { "encoding", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	},
}
