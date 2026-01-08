#!/usr/bin/env python3

import os
import subprocess
import sys
from pathlib import Path

try:
    import inquirer
except ImportError:
    print("Ошибка: Установите библиотеку inquirer (pip install inquirer)")
    sys.exit(1)

# Базовый путь, где лежат ваши категории проектов
# Можно переопределить через переменную окружения PROJECTS_ROOT
BASE_PATH = Path(os.getenv("MO_BASE_PATH", Path.home() / "Documents/MagnumOpus"))

PROJECT_TYPES = ["MiniProjects", "GigaProjects", "ContentProjects"]


def get_project_data() -> tuple[str, str, bool]:
    questions = [
        inquirer.List(
            "type",
            message="Выберите тип проекта",
            choices=PROJECT_TYPES,
        ),
        inquirer.Text(
            "name",
            message="Введите название проекта",
            validate=lambda _, x: len(x.strip()) > 0 or "Название не может быть пустым",
        ),
        inquirer.Confirm(
            "open_nvim",
            message="Открыть БАЗА.md в Neovim после создания?",
            default=True,
        ),
    ]

    answers = inquirer.prompt(questions)
    if answers is None:
        print("Отмена операции.")
        sys.exit(0)

    return (str(answers["type"]), str(answers["name"]), answers["open_nvim"])


def create_project_structure(project_type: str, project_name: str) -> Path:
    # Формируем пути
    folder_path = BASE_PATH / project_type / project_name
    basa_path = folder_path / "БАЗА.md"

    # Создаем директорию
    try:
        folder_path.mkdir(parents=True, exist_ok=True)
        print(f"  -* Директория создана: {folder_path}")
    except Exception as e:
        print(f"Ошибка при создании папки: {e}")
        sys.exit(1)

    basa_content = (
        f"# БАЗА: {project_name}\n"
        "```dataview\n"
        "LIST\n"
        "WHERE file.folder = this.file.folder AND file.name != this.file.name\n"
        "SORT file.name ASC\n"
        "```\n\n"
        "# Почему\n\n\n"
        "# Цель\n\n\n"
    )

    if not basa_path.exists():
        with open(basa_path, "w", encoding="utf-8") as f:
            _ = f.write(basa_content)
        print(f"  -* Файл создан: {basa_path}")
    else:
        print(f"  -! Файл {basa_path} уже существует. Пропускаю создание.")

    return basa_path


def main():
    if not BASE_PATH.exists():
        print(f"Ошибка: Базовый путь {BASE_PATH} не найден.")
        print("Пожалуйста, проверьте переменную PROJECTS_ROOT или создайте папку.")
        sys.exit(1)

    project_type, project_name, open_nvim = get_project_data()
    project_name = project_name.strip()

    print(f"Создание проекта '{project_name}' в категории '{project_type}'...")

    basa_file = create_project_structure(project_type, project_name)

    print(f"DONE: Проект {project_name} готов.")

    if open_nvim:
        print(f"Запуск Neovim для {basa_file}...")
        _ = subprocess.run(["NVIM_APPNAME=litex", "nvim", str(basa_file)])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nПрервано пользователем.")
        sys.exit(0)
