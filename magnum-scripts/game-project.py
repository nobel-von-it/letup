#!/usr/bin/env python

import datetime
import os
import subprocess
import sys
from pathlib import Path

try:
    import inquirer
except ImportError:
    print("Ошибка: Установите библиотеку inquirer (pip install inquirer)")
    sys.exit(1)

# --- НАСТРОЙКИ СПИСКА ЖАНРОВ ---
# Вы можете добавлять или удалять жанры здесь.
# Скрипт сам приведет их к нижнему регистру и заменит пробелы на "-"
GENRE_OPTIONS = [
    "Action",
    "RPG",
    "Soulslike",
    "Metroidvania",
    "Platformer",
    "Open World",
    "Survival Horror",
    "Shooter",
    "Adventure",
    "Strategy",
    "Immersive Sim",
    "Roguelike",
]

# Базовый путь для игровых проектов
BASE_PATH = Path(
    os.getenv("PROJECTS_ROOT", Path.home() / "Documents/MagnumOpus/ContentProjects")
)


def get_russian_date():
    """Возвращает дату в формате 'Месяц ГГГГ' на русском"""
    months = [
        "Январь",
        "Февраль",
        "Март",
        "Апрель",
        "Май",
        "Июнь",
        "Июль",
        "Август",
        "Сентябрь",
        "Октябрь",
        "Ноябрь",
        "Декабрь",
    ]
    now = datetime.datetime.now()
    return f"{months[now.month - 1]} {now.year}"


def get_project_data() -> tuple[str, list[str], bool]:
    questions = [
        inquirer.Text(
            "name",
            message="Введите название игры",
            validate=lambda _, x: len(x.strip()) > 0 or "Название не может быть пустым",
        ),
        inquirer.Checkbox(
            "genres",
            message="Выберите жанры (Пробел — выбор, Enter — подтверждение)",
            choices=GENRE_OPTIONS,
        ),
        inquirer.Confirm(
            "open_nvim",
            message="Открыть файлы в Neovim после создания?",
            default=True,
        ),
    ]

    answers = inquirer.prompt(questions)
    if answers is None:
        print("Отмена операции.")
        sys.exit(0)

    return (str(answers["name"]), list(answers["genres"]), answers["open_nvim"])


def format_genres(genres_list: list[str]) -> str:
    """Форматирует жанры: в нижний регистр, пробелы заменяет на дефисы"""
    formatted = [g.lower().strip().replace(" ", "-") for g in genres_list]
    return ", ".join(formatted)


def create_project_structure(game_name: str, genres: list[str]) -> tuple[Path, Path]:
    folder_path = BASE_PATH / ("Пройти " + game_name)
    basa_path = folder_path / "БАЗА.md"
    review_path = folder_path / "Ревью.md"

    current_date_ru = get_russian_date()
    genres_string = format_genres(genres)

    try:
        folder_path.mkdir(parents=True, exist_ok=True)
        print(f"  [+] Директория создана: {folder_path}")
    except Exception as e:
        print(f"Ошибка при создании папки: {e}")
        sys.exit(1)

    # 1. Содержимое БАЗА.md
    basa_content = (
        f"# БАЗА: {game_name}\n"
        "```dataview\n"
        "LIST\n"
        "WHERE file.folder = this.file.folder AND file.name != this.file.name\n"
        "SORT file.name ASC\n"
        "```\n\n"
        "# Почему\n\n\n"
        "# Цель\n\n\n"
    )

    # 2. Содержимое Ревью.md
    review_template = (
        "---\n"
        "type: game-review\n"
        f"game: {game_name}\n"
        f"genres: {genres_string}\n"
        f"completed: {current_date_ru}\n"
        "time: \n"
        "status: completed\n"
        "---\n\n"
        f"# {game_name}\n\n"
        "---\n"
        "## Оценка\n\n"
        "### Геймплей\n\n\n"
        "### Сюжет\n\n\n"
        "### Музыка\n\n\n"
        "### Графика\n\n\n"
        "### Сеттинг\n\n\n"
        "### Атмосфера\n\n\n"
        "### Сложность\n\n\n"
        "### Управление\n\n\n"
        "### Оптимизация\n\n\n"
        "## Итог\n\n"
    )

    # Запись файлов
    for path, content in [(basa_path, basa_content), (review_path, review_template)]:
        if not path.exists():
            with open(path, "w", encoding="utf-8") as f:
                _ = f.write(content)
            print(f"  [+] Файл создан: {path.name}")
        else:
            print(f"  [!] Файл {path.name} уже существует.")

    return basa_path, review_path


def main():
    if not BASE_PATH.exists():
        BASE_PATH.mkdir(parents=True, exist_ok=True)

    game_name, genres, open_nvim = get_project_data()
    game_name = game_name.strip()

    print(f"\nСоздание проекта игры: '{game_name}'...")

    basa_file, _ = create_project_structure(game_name, genres)

    print(f"DONE: Проект '{game_name}' готов.\n")

    if open_nvim:
        print("Запуск Neovim...")
        editor = os.getenv("MO_EDITOR", "nvim")
        _ = subprocess.run([editor, str(basa_file)])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nПрервано пользователем.")
        sys.exit(0)
