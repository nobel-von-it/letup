#!/usr/bin/env python

import json
import os
import sys
from pathlib import Path
from typing import cast

try:
    import inquirer
except ImportError:
    print("Please install inquirer")
    sys.exit(1)


def is_command_available(command: str) -> bool:
    return os.system(f"command -v {command}") == 0


def pacman_install(packages: list[str]) -> None:
    os.system(f"sudo pacman -S --needed {' '.join(packages)}")


def aur_install(packages: list[str]) -> None:
    if is_command_available("paru"):
        paru_install(packages)
    elif is_command_available("yay"):
        yay_install(packages)
    else:
        print("Please install paru or yay")
        sys.exit(1)


def yay_install(packages: list[str]) -> None:
    os.system(f"yay -S --needed {' '.join(packages)}")


def paru_install(packages: list[str]) -> None:
    os.system(f"paru -S --needed {' '.join(packages)}")


def main() -> None:
    questions = [
        inquirer.Path(
            "path_to_packages_json",
            message="Path to packages json file",
            default="",
        )
    ]

    answers = inquirer.prompt(questions)
    if answers is None:
        print("Aborted")
        sys.exit(1)

    packages_json_path = Path(answers["path_to_packages_json"])
    if not packages_json_path.exists():
        print("Packages json file not found")
        sys.exit(1)

    with open(packages_json_path, "r") as f:
        packages = json.load(f)

    pacman_packages = cast(list[str], packages["pacman"])
    aur_packages = cast(list[str], packages["aur"])

    if pacman_packages:
        pacman_install(pacman_packages)

    if aur_packages:
        aur_install(aur_packages)

    print("Packages installed")


if __name__ == "__main__":
    main()
