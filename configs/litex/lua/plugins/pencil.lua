return {
	"preservim/vim-pencil",
	lazy = false,
	init = function()
		-- Настройки карандаша
		vim.g["pencil#wrapModeDefault"] = "soft" -- мягкие переносы
		vim.g["pencil#autoformat"] = 1 -- автоформатирование при наборе
		vim.g["pencil#joinspaces"] = 0 -- один пробел после точки (современно)
	end,
	config = function()
		-- Включаем Pencil автоматически для текстовых файлов
		vim.api.nvim_create_autocmd({ "FileType" }, {
			pattern = { "markdown", "text", "plain" },
			callback = function()
				vim.cmd("PencilSoft")
			end,
		})
	end,
}
