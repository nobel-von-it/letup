import os

import ollama


def translate_text(text: str, model: str = "gemma3:4b") -> str:
    """Отправляет текст в Ollama для перевода."""

    system_prompt = (
        "You are a professional translator. Translate the following text into Russian. "
        "The source language is either English or Japanese. "
        "Maintain the original tone and formatting. "
        "Provide ONLY the translation, without any explanations or comments."
    )

    try:
        response = ollama.generate(
            model=model,
            system=system_prompt,
            prompt=f"Translate this text to Russian:\n\n{text}",
            stream=False,
        )
        return str(response["response"]).strip()
    except Exception as e:
        return f"Ошибка при обращении к Ollama: {e}"


def main():
    print("--- Переводчик (Gemma 3:4b) ---")
    print("Введите текст для перевода или полный путь к .txt файлу:")

    user_input = input("> ").strip()

    if not user_input:
        print("Пустой ввод.")
        return

    if os.path.isfile(user_input):
        try:
            with open(user_input, "r", encoding="utf-8") as file:
                text_to_translate = file.read()
            print(f"--- Чтение из файла: {user_input} ---")
        except Exception as e:
            print(f"Не удалось прочитать файл: {e}")
            return
    else:
        text_to_translate = user_input

    print("\nПеревод...")
    result = translate_text(text_to_translate)

    print("\n--- РЕЗУЛЬТАТ ---")
    print(result)
    print("------------------")


if __name__ == "__main__":
    main()
