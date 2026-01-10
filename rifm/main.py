import os
import sys

import requests
from bs4 import BeautifulSoup


class Style:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BOLD = "\033[1m"
    END = "\033[0m"


class Rhymes:
    def __init__(
        self, word: str, exact_rhymes: list[str], less_exact_rhymes: list[str]
    ):
        self.word = word
        self.exact_rhymes = exact_rhymes
        self.less_exact_rhymes = less_exact_rhymes


def get_rhymes(word: str) -> Rhymes | None:
    url = f"https://rifme.net/r/{word}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    rhymes = Rhymes(word, [], [])
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")

        # Парсим точные рифмы
        pre_exact = soup.find("ul", id="tochnye")
        if pre_exact:
            rhymes.exact_rhymes = [
                str(li.get("data-w"))
                for li in pre_exact.find_all("li")
                if li.get("data-w")
            ]

        # Парсим менее точные рифмы
        pre_less = soup.find("ul", id="meneestrogie")
        if pre_less:
            rhymes.less_exact_rhymes = [
                str(li.get("data-w"))
                for li in pre_less.find_all("li")
                if li.get("data-w")
            ]

        return rhymes
    except Exception as e:
        print(f"Ошибка при запросе: {e}")
        return None


def print_as_columns(words_list: list[str], color_style: str):
    """Выводит список слов колонками, как ls"""
    if not words_list:
        return

    # Получаем ширину терминала
    try:
        term_width = os.get_terminal_size().columns
    except OSError:
        term_width = 80

    # Находим длину самого длинного слова + запас на пробел
    max_len = max(len(w) for w in words_list) + 2
    # Считаем количество колонок
    num_cols = max(1, term_width // max_len)

    # Печатаем слова
    for i, word in enumerate(words_list):
        # Выравниваем слово по левому краю в пределах колонки
        print(f"{color_style}{word:<{max_len}}{Style.END}", end="")
        # Если заполнили ряд, переходим на новую строку
        if (i + 1) % num_cols == 0:
            print()
    print()  # Финальный перенос строки, если список закончился не на краю


def print_styled_output(result: Rhymes):
    # Заголовок
    print(
        f"\n{Style.BOLD}{Style.HEADER} РИФМЫ ДЛЯ СЛОВА: {result.word.upper()} {Style.END}"
    )

    # Считаем ширину разделителя по размеру терминала
    try:
        line_width = os.get_terminal_size().columns
    except OSError:
        line_width = 80

    print(f"{Style.YELLOW}{'━' * line_width}{Style.END}")

    # Блок точных рифм
    if result.exact_rhymes:
        print(
            f"{Style.GREEN}{Style.BOLD}● ТОЧНЫЕ РИФМЫ ({len(result.exact_rhymes)}):{Style.END}"
        )
        print_as_columns(result.exact_rhymes, Style.GREEN)
    else:
        print(f"{Style.YELLOW}● Точных рифм не найдено.{Style.END}")

    print(f"{Style.YELLOW}{'─' * line_width}{Style.END}")

    # Блок менее точных рифм
    if result.less_exact_rhymes:
        print(
            f"{Style.BLUE}{Style.BOLD}● МЕНЕЕ ТОЧНЫЕ РИФМЫ ({len(result.less_exact_rhymes)}):{Style.END}"
        )
        print_as_columns(result.less_exact_rhymes, Style.BLUE)
    else:
        print(f"{Style.YELLOW}● Менее точных рифм не найдено.{Style.END}")

    print(f"{Style.YELLOW}{'━' * line_width}{Style.END}\n")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python rhymes.py <слово>")
        sys.exit(1)

    search_word = sys.argv[1]
    result = get_rhymes(search_word)

    if result:
        print_styled_output(result)
    else:
        print("Не удалось получить результат.")
