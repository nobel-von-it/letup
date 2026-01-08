local keymap = vim.keymap

keymap.set("n", "<leader>e", vim.cmd.Explore, { desc = "Проводник" })
keymap.set("i", "jk", "<ESC>", { desc = "Выход в Normal mode через jk" })
keymap.set("n", "<leader>n", vim.cmd.nohl, { desc = "Сброс подсветки поиска" })

-- Навигация по мягким переносам (gj/gk вместо j/k)
-- Теперь стрелочки или j/k ходят по строкам на экране, а не по абзацам
keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Быстрое включение/выключение плагинов для письма
keymap.set("n", "<leader>z", ":ZenMode<CR>", { desc = "Режим фокуса (ZenMode)" })
keymap.set("n", "<leader>t", ":Twilight<CR>", { desc = "Подсветка абзаца (Twilight)" })

-- Управление проверкой орфографии
keymap.set(
	"n",
	"<leader>ss",
	":set spell!<CR>",
	{ desc = "Переключить проверку орфографии" }
)

-- Быстрые действия с текстом
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Переместить блок вниз" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Переместить блок вверх" })

-- Центрирование экрана при перемещении
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")
