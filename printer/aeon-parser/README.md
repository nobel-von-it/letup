# 📚 Universal Article & Essay Parser
### Парсер статей и эссе для типографической верстки и печати буклетов

Универсальный инструмент для автоматического скачивания, очистки и форматирования статей и эссе с популярных публицистических платформ. Генерирует типографически чистый Markdown с метаданными YAML Frontmatter, полностью готовый для компиляции в PDF/буклеты через `typst`, `pandoc`, `booker.sh` и `pdfjam`.

---

## ⚡ Особенности

- **Автоопределение источника**: больше не нужно указывать сайт вручную — детектор сам распознаёт домен и выбирает нужный движок.
- **Пакетная загрузка**: передавайте одну ссылку, несколько ссылок через пробел или текстовый файл со списком статей.
- **Нумерация глав для сборников (`-n`)**: при скачивании нескольких статей автоматически проставляются номера глав (`# 1. Заголовок`, `# 2. Заголовок`), а файлы нумеруются по порядку (`01_name.md`, `02_name.md`).
- **Глубокая типографическая очистка**:
  - Удаление баннеров, виджетов соцсетей, аудиоплееров, форм подписки и донатов.
  - Сохранение форматирования: ссылок, курсива, полужирного начертания и цитат.
  - Разделение стихотворных строф и сплошной прозы в цитатах.
  - Корректная обработка буквиц (dropcaps) и иллюстраций с подписями.
- **Модульная архитектура**: легко добавить новый сайт за пару минут.

---

## 🌐 Поддерживаемые сайты

| Сайт | Домен | Особенности парсинга |
| :--- | :--- | :--- |
| **Aeon** | `aeon.co` | Эссе, буквицы, биография автора, стихи/цитаты, удаление аудиоплееров |
| **Psyche** | `psyche.co` | Сестринское издание Aeon (Ideas и Guides), структурированные разделы |
| **Quanta Magazine** | `quantamagazine.org` | Научные лонгриды, деки, авторы, даты, математические термины, иллюстрации |
| **The Conversation** | `theconversation.com` | Академический анализ, несколько авторов с аффилиациями, подзаголовки |
| **Универсальный fallback** | *любой сайт* | Извлечение статей по семантике HTML5 (`<article>`), OpenGraph и Schema.org/JSON-LD |

---

## 🚀 Установка

Для работы требуется Python 3.10+ и библиотеки из `requirements.txt`.

### Автоматическая установка (Arch Linux / Pop!_OS / Ubuntu)
```bash
./install.sh
# или через ключ:
./main.py -i
```
Скрипт установит системные утилиты (`pandoc`, `typst`, `pdfjam`, `calibre`) и создаст виртуальное окружение `.venv` с нужными библиотеками.

### Ручная установка
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 📖 Примеры использования

### 1. Скачивание одной статьи
Сайт распознаётся автоматически:
```bash
./main.py "https://aeon.co/essays/humans-did-not-invent-art-it-was-the-other-way-around"
```
Файл сохранится как `how_art_invented_humanity.md`.

---

### 2. Скачивание нескольких статей одновременно
Можно передавать любое количество ссылок с разных сайтов:
```bash
./main.py \
  "https://aeon.co/essays/humans-did-not-invent-art-it-was-the-other-way-around" \
  "https://psyche.co/ideas/writing-letters-is-a-spiritual-practice-for-our-age-of-speed" \
  "https://www.quantamagazine.org/genome-duplication-is-a-radical-evolutionary-gamble-20260902/" \
  "https://theconversation.com/amid-grinding-war-protesting-ukrainians-still-want-their-voices-and-values-heard-at-home-287823"
```
Каждая статья скачается отдельно с выводом прогресса `[1/4]`, `[2/4]`, `[3/4]`, `[4/4]`.

---

### 3. Сборка статей в главы для брошюры (`-n` и `-d`)
Параметр `-n` задаёт начальный номер главы. Для каждого следующего URL номер автоматически увеличивается на 1, а в заголовках статей появляется `# 1. Заголовок`, `# 2. Заголовок`:
```bash
./main.py -d ./booklet_articles -n 1 \
  "https://aeon.co/..." \
  "https://psyche.co/..." \
  "https://quantamagazine.org/..."
```
В папке `./booklet_articles/` появятся пронумерованные файлы:
- `01_humans_did_not_invent_art.md`
- `02_writing_letters_is_a_spiritual_practice.md`
- `03_genome_duplication_is_a_radical.md`

---

### 4. Скачивание списка ссылок из файла
Создайте текстовый файл со ссылками (по одной на строку), например `reading_list.txt`:
```text
# Мой список для чтения
https://aeon.co/essays/humans-did-not-invent-art-it-was-the-other-way-around
https://psyche.co/ideas/writing-letters-is-a-spiritual-practice-for-our-age-of-speed
https://www.quantamagazine.org/genome-duplication-is-a-radical-evolutionary-gamble-20260902/
```
Запустите скачивание:
```bash
./main.py reading_list.txt -d ./downloaded -n 1
```

---

### 5. Сохранение в файл с заданным именем
```bash
./main.py -o my_custom_article.md "https://aeon.co/..."
```

---

### 6. Скачивание локально сохранённого HTML-файла
Если статья была сохранена в файл `saved_page.html`:
```bash
./main.py saved_page.html
```
Детектор автоматически проанализирует теги `<link rel="canonical">` и `og:url` внутри HTML, определит исходный сайт и применит правильный парсер.

---

### 7. Принудительный выбор парсера (`-p / --parser`)
Если вы хотите переопределить автоопределение:
```bash
./main.py -p aeon "https://..."
./main.py -p generic "https://any-blog.com/post-123"
```

---

### 8. Просмотр списка поддерживаемых парсеров
```bash
./main.py --list-parsers
```

---

## 🖨️ Полный цикл: от веб-ссылки до физической книги

1. **Скачиваем статьи с нумерацией глав**:
   ```bash
   ./main.py -d ./my_book -n 1 url1 url2 url3
   ```
2. **Объединяем статьи в один Markdown или конвертируем каждую**:
   ```bash
   cat my_book/*.md > combined.md
   ```
3. **Собираем в тетрадный буклет для печати**:
   ```bash
   ../booker.sh combined.md
   ```
4. **Печатаем**:
   - Отправьте получившийся `*_booklet.pdf` на принтер.
   - В настройках CUPS выберите: **«Двусторонняя печать по КОРОТКОМУ краю»** (Two-Sided Short Edge).
   - Согните листы пополам и сшейте в тетрадь.

---

## 🛠️ Параметры командной строки

| Флаг | Описание |
| :--- | :--- |
| `urls` | Одна или несколько ссылок, файлов `.html` или текстовых файлов со ссылками |
| `-o, --output PATH` | Имя выходного файла (для одной ссылки) или папка (для нескольких) |
| `-d, --output-dir DIR` | Папка для сохранения Markdown-файлов (по умолчанию: `.`) |
| `-n, --chapter NUM` | Начальный номер главы (автоинкремент для каждой следующей ссылки) |
| `-p, --parser NAME` | Принудительный выбор парсера (`aeon`, `psyche`, `quanta`, `theconversation`, `generic`) |
| `-l, --list-parsers` | Вывести список всех доступных парсеров и доменов |
| `-i, --install` | Запустить установку системных пакетов и зависимостей |
| `-h, --help` | Подробная интерактивная справка прямо в терминале |

---

## 🧩 Архитектура проекта и добавление нового сайта

Файловая структура:
```
aeon-parser/
├── main.py                     # CLI точка входа
├── install.sh                  # Скрипт установки зависимостей
├── requirements.txt            # Python-зависимости (bs4, requests, lxml)
├── README.md                   # Данный юзер-гайд
└── parsers/
    ├── __init__.py             # Экспорт классов и функций
    ├── base.py                 # BaseParser, Article, clean_inline_html, format_markdown
    ├── detector.py             # Реестр парсеров и автодетектор сайтов
    ├── aeon.py                 # Парсер Aeon.co
    ├── psyche.py               # Парсер Psyche.co
    ├── quantamagazine.py       # Парсер QuantaMagazine.org
    ├── theconversation.py      # Парсер TheConversation.com
    └── generic.py              # Универсальный fallback парсер
```

### Добавление нового сайта за 3 шага:
Создайте файл в `parsers/mysite.py`:

```python
from bs4 import BeautifulSoup
from .base import BaseParser, Article, clean_inline_html, clean_title
from .detector import register_parser

@register_parser
class MySiteParser(BaseParser):
    name = "mysite"
    site_display_name = "My Favorite Site"
    domains = ["mysite.com", "mysite.org"]

    def extract(self, soup: BeautifulSoup, source_url: str, raw_html: str) -> Article:
        title = clean_title(soup.find("h1"))
        author = soup.select_one(".author").get_text(strip=True) if soup.select_one(".author") else ""
        
        nodes = []
        for p in soup.select("article p"):
            nodes.append(("p", clean_inline_html(p)))
            
        return Article(
            title=title,
            author=author,
            source_url=source_url,
            nodes=nodes,
            site_name=self.site_display_name,
        )
```
И импортируйте его в `parsers/__init__.py`. Сайт автоматически начнёт определяться детектором!
