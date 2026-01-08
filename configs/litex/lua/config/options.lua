local opt = vim.opt

-- Основные настройки для текста
opt.wrap = true -- Включаем перенос строк
opt.linebreak = true -- Не рвем слова при переносе
opt.breakindent = true -- Сохраняем отступ при переносе строки

-- Проверка орфографии
opt.spell = true
opt.spelllang = { "en_us", "ru" } -- Поддержка английского и русского

-- Интерфейс
opt.number = false -- Номера строк обычно мешают при письме
opt.relativenumber = false
opt.cursorline = true -- Подсветка строки, где мы сейчас
opt.laststatus = 3 -- Глобальный статус-бар снизу

-- Markdown и скрытие символов
opt.conceallevel = 2 -- Скрывать символы разметки (ссылки, жирность становится красивой)
opt.concealcursor = "nc" -- Показывать символы только в режиме вставки

-- Табы (стандарт для Markdown — 2 или 4 пробела)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- Поиск
opt.ignorecase = true
opt.smartcase = true

-- Память и откат
opt.undofile = true -- Сохранять историю изменений после закрытия файла
