#!/usr/bin/env python3
"""
Universal Article & Essay Parser
Extracts clean, publication-ready Markdown and EPUB/Typst-ready articles from
Aeon, Psyche, Quanta Magazine, The Conversation, and other publication sites.
Formatted for booklet printing tools like `booker`, `pandoc`, and `typst`.
"""

import sys
import os
import re
import argparse
from typing import List, Optional, Tuple

# Ensure package imports work regardless of working directory
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from parsers import (
    Article,
    BaseParser,
    clean_inline_html,
    format_markdown,
    detect_parser,
    get_parser,
    list_available_parsers,
    AeonParser,
)

DEFAULT_SAMPLE_URL = "https://aeon.co/essays/humans-did-not-invent-art-it-was-the-other-way-around"


def extract_aeon_essay(url_or_html: str) -> dict:
    """
    Backward-compatibility function for extracting Aeon essays.
    Returns dictionary with article fields.
    """
    parser = AeonParser()
    article = parser.parse(url_or_html)
    return article.to_dict()


def run_install():
    """Execute install.sh script for system and python dependencies."""
    install_script = os.path.join(SCRIPT_DIR, "install.sh")
    if os.path.exists(install_script):
        os.system(f"bash '{install_script}'")
    else:
        print("[-] Ошибка: install.sh не найден")


def slugify(text: str, max_length: int = 70) -> str:
    """Generate a clean filesystem slug from a title."""
    slug = re.sub(r'[^a-zA-Z0-9_-]+', '_', text).strip('_').lower()
    if not slug:
        slug = "article"
    return slug[:max_length].rstrip('_')


def load_urls_from_args(raw_args: List[str]) -> List[str]:
    """
    Extract URLs from command-line arguments. Supports raw URLs, local files,
    and text files containing URLs (one per line).
    """
    urls: List[str] = []
    for item in raw_args:
        item = item.strip()
        if not item:
            continue
        # Check if argument is a text file containing URLs
        if (item.endswith(".txt") or item.startswith("@")) and os.path.isfile(item.lstrip("@")):
            file_path = item.lstrip("@")
            with open(file_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        urls.append(line)
        else:
            urls.append(item)
    return urls


def process_article(
    url_or_path: str,
    output_path: Optional[str] = None,
    output_dir: str = ".",
    chapter_num: Optional[int] = None,
    forced_parser: Optional[str] = None,
) -> Tuple[bool, str]:
    """
    Parse a single article URL or file and write the resulting Markdown.
    Returns (success, result_message_or_filepath).
    """
    # 1. Detect or resolve parser
    try:
        parser = get_parser(forced_parser, url_or_path)
    except Exception as e:
        return False, f"Ошибка выбора парсера: {e}"

    print(f"[*] Fetching & parsing: {url_or_path}")
    print(f"[+] Detected parser: {parser.site_display_name} ({parser.name})")

    # 2. Extract article
    try:
        article = parser.parse(url_or_path)
    except Exception as e:
        return False, f"Ошибка при загрузке/парсинге: {e}"

    print(f"[+] Title: {article.title}")
    if article.subtitle:
        sub_preview = article.subtitle[:75] + ("..." if len(article.subtitle) > 75 else "")
        print(f"[+] Subtitle: {sub_preview}")
    if article.author:
        print(f"[+] Author: {article.author}")
    if article.date:
        print(f"[+] Date: {article.date}")
    print(f"[+] Total body blocks: {len(article.nodes)}")

    # 3. Determine output file path
    if not output_path:
        slug = slugify(article.title)
        if chapter_num is not None:
            filename = f"{chapter_num:02d}_{slug}.md"
        else:
            filename = f"{slug}.md"
        output_path = os.path.join(output_dir, filename) if output_dir else filename

    # 4. Generate Markdown content
    md_content = format_markdown(article, chapter_num=chapter_num)

    # 5. Save to file
    out_dir = os.path.dirname(output_path)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(md_content)

    print(f"[✓] Saved clean Markdown to: {output_path}")
    return True, output_path


def main():
    parser = argparse.ArgumentParser(
        description="""\
========================================================================
       Универсальный парсер статей и эссе для печати буклетов
========================================================================
Автоматически скачивает статьи, очищает от рекламы/виджетов и формирует
чистый Markdown с YAML Frontmatter для typst, pandoc и booker.sh.

Поддерживает сайты:
  • Aeon (aeon.co)
  • Psyche (psyche.co)
  • Quanta Magazine (quantamagazine.org)
  • The Conversation (theconversation.com)
  • Универсальный fallback для любых других сайтов (HTML5 / Schema.org)

Сайт определяется АВТОМАТИЧЕСКИ по домену или мета-тегам HTML.
Вручную указывать парсер не требуется.""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
------------------------------------------------------------------------
ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:
------------------------------------------------------------------------
  1. Скачать одну статью (сайт определится автоматически):
     ./main.py https://aeon.co/essays/humans-did-not-invent-art...

  2. Скачать несколько статей с разных сайтов:
     ./main.py https://aeon.co/... https://psyche.co/... https://quantamagazine.org/...

  3. Пакетная загрузка в папку с автонумерацией глав (1, 2, 3...):
     ./main.py -d ./articles -n 1 url1 url2 url3
     # Создадутся файлы:
     #   articles/01_title_one.md
     #   articles/02_title_two.md

  4. Скачивание списка ссылок из текстового файла:
     ./main.py urls.txt -d ./output
     # или через префикс @:
     ./main.py @my_reading_list.txt

  5. Указать конкретное имя выходного файла:
     ./main.py -o custom_name.md https://aeon.co/...

  6. Посмотреть список поддерживаемых парсеров:
     ./main.py --list-parsers

  7. Собрать скачанную статью в буклет для двусторонней печати:
     ../booker.sh 01_title_one.md
------------------------------------------------------------------------""",
    )
    parser.add_argument(
        "urls",
        nargs="*",
        metavar="URL",
        help="Одна или несколько ссылок на статьи, локальные HTML-файлы "
             "или .txt файлы со списками ссылок (по одной на строку). "
             "Если ничего не передано, используется тестовая статья с Aeon.",
    )
    parser.add_argument(
        "-o", "--output",
        metavar="PATH",
        help="Имя выходного файла (для одной ссылки) или папка назначения (для нескольких ссылок)",
    )
    parser.add_argument(
        "-d", "--output-dir",
        default=".",
        metavar="DIR",
        help="Папка для сохранения скачанных Markdown-файлов (по умолчанию: текущая папка)",
    )
    parser.add_argument(
        "-n", "--chapter",
        type=int,
        metavar="NUM",
        help="Начальный номер главы (например, 1 для '# 1. Заголовок'). "
             "При передаче нескольких ссылок номер автоматически инкрементируется (1, 2, 3...)",
    )
    parser.add_argument(
        "-p", "--parser",
        default="auto",
        metavar="NAME",
        help="Принудительный выбор парсера ('aeon', 'psyche', 'quanta', 'theconversation', 'generic'). "
             "По умолчанию: 'auto' (автодетект)",
    )
    parser.add_argument(
        "-b", "--booklet",
        nargs="?",
        const="auto",
        metavar="NAME_OR_DIR",
        help="Собрать статьи в печатный буклет через booker.sh. "
             "Можно вызвать отдельно на существующую папку: ./main.py -b ./my_folder",
    )
    parser.add_argument(
        "-l", "--list-parsers",
        action="store_true",
        help="Показать список доступных парсеров и доменов",
    )
    parser.add_argument(
        "-i", "--install",
        action="store_true",
        help="Установить все зависимости системы и Python (Arch Linux, Pop!_OS / Ubuntu)",
    )

    args = parser.parse_args()

    # Handle install
    if args.install:
        run_install()
        return

    # Handle list parsers
    if args.list_parsers:
        print("Available site parsers:")
        for p in list_available_parsers():
            print(f"  • {p['name']:<18} | {p['display_name']:<16} | Domains: {p['domains']}")
        return

    # Collect URLs
    raw_urls = args.urls

    # Check for standalone booklet invocation on an existing directory
    if args.booklet and args.booklet != "auto" and os.path.isdir(args.booklet) and not raw_urls:
        booker_script = os.path.join(os.path.dirname(SCRIPT_DIR), "booker.sh")
        if not os.path.exists(booker_script):
            booker_script = os.path.join(SCRIPT_DIR, "booker.sh")
        if os.path.exists(booker_script):
            os.system(f"bash '{booker_script}' '{args.booklet}'")
            return
        else:
            print(f"[-] Ошибка: {booker_script} не найден")
            sys.exit(1)

    urls = load_urls_from_args(raw_urls)

    if not urls:
        print(f"[*] Ссылки не переданы, используется статья по умолчанию:")
        print(f"    {DEFAULT_SAMPLE_URL}")
        urls = [DEFAULT_SAMPLE_URL]

    total = len(urls)
    success_count = 0
    fail_count = 0

    # Ensure output directory exists
    output_dir = args.output_dir
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    # Determine base chapter number
    current_chapter = args.chapter

    print(f"\n==========================================================")
    print(f"    Universal Article Parser (Total items: {total})")
    print(f"==========================================================")

    for i, url in enumerate(urls, 1):
        print(f"\n[{i}/{total}] " + "-" * 48)

        target_file = None

        if total == 1 and args.output:
            # Single file explicit path or dir
            if os.path.isdir(args.output) or args.output.endswith(os.sep):
                output_dir = args.output
            else:
                target_file = args.output
        elif total > 1 and args.output:
            # If -o is provided for multiple URLs, treat as output directory
            output_dir = args.output

        if not target_file and output_dir != ".":
            # Will be resolved inside process_article, but prefix with output_dir
            pass

        chapter_arg = current_chapter
        if current_chapter is not None:
            current_chapter += 1

        # If saving into a specific output directory and no fixed filename
        if not target_file and output_dir and output_dir != ".":
            # Temporary target_file prefix or placeholder
            pass

        forced = None if args.parser == "auto" else args.parser
        ok, res = process_article(
            url_or_path=url,
            output_path=os.path.join(output_dir, target_file) if (target_file and output_dir != ".") else target_file,
            output_dir=output_dir,
            chapter_num=chapter_arg,
            forced_parser=forced,
        )

        if ok:
            success_count += 1
        else:
            fail_count += 1
            print(f"[-] {res}")

    print(f"\n==========================================================")
    if fail_count == 0:
        print(f"[✓] Успешно завершено! Обработано статей: {success_count}/{total}")
    else:
        print(f"[!] Завершено с ошибками. Успешно: {success_count}, Ошибок: {fail_count}")
    print(f"==========================================================\n")

    # If --booklet was requested, build booklet from output_dir
    if args.booklet and success_count > 0:
        booker_script = os.path.join(os.path.dirname(SCRIPT_DIR), "booker.sh")
        if not os.path.exists(booker_script):
            booker_script = os.path.join(SCRIPT_DIR, "booker.sh")

        if os.path.exists(booker_script):
            title = "" if args.booklet == "auto" else args.booklet
            cmd = f"bash '{booker_script}' '{output_dir}'"
            if title and not os.path.isdir(title):
                cmd += f" '{title}'"
            print(f"[*] Автоматическая сборка печатного буклета из '{output_dir}'...")
            os.system(cmd)

    if fail_count > 0 and success_count == 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
