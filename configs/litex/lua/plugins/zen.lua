return {
	"folke/zen-mode.nvim",
	opts = {
		window = {
			backdrop = 0.95, -- немного затемняем фон
			width = 100, -- ширина текстового окна
			options = {
				signcolumn = "no", -- убираем боковую панель
				number = false, -- убираем номера строк
				relativenumber = false,
				cursorline = false, -- убираем подсветку строки для чистоты
			},
		},
		plugins = {
			twilight = { enabled = true }, -- автоматически включаем Twilight в Zen-mode
		},
	},
}
