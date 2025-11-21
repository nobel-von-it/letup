#!/usr/bin/env python

import os
import sys
from pathlib import Path

try:
    import inquirer
except ImportError:
    print("Please install inquirer")
    sys.exit(1)


SRC_CONFIG_PATH = Path(__file__).parent / "configs"
DEST_CONFIG_PATH = Path.home() / ".config"

CONFIG_NAMES = [
    "yazi",
    "alacritty",
    "zed",
]


def check_configs_exist(src_path: Path, config_list: list[str]) -> list[str]:
    not_founded = []
    for config in config_list:
        if not (src_path / config).exists():
            not_founded.append(config)

    return not_founded


def inquirer_questions() -> tuple[Path, Path, list[str]]:
    questions = [
        inquirer.Path(
            "src",
            message="Source directory",
            default=SRC_CONFIG_PATH,
        ),
        inquirer.Path(
            "dest",
            message="Destination directory",
            default=DEST_CONFIG_PATH,
        ),
        inquirer.Checkbox(
            "configs",
            message="Configs to link",
            choices=CONFIG_NAMES,
            default=[],
        ),
    ]
    answers = inquirer.prompt(questions)
    if answers is None:
        print("Aborted")
        sys.exit(1)

    return (Path(answers["src"]), Path(answers["dest"]), answers["configs"])


def link_configs(src_path: Path, dest_path: Path, config_list: list[str]) -> None:
    for config in config_list:
        full_dest_path = dest_path / config
        print(f"  -* Checking {full_dest_path}")
        if full_dest_path.exists():
            if full_dest_path.is_symlink():
                print(f"    -* Removing symlink {full_dest_path}")
                os.unlink(full_dest_path)
            else:
                print(f"    -* {full_dest_path} is not a symlink")
                print("Aborted")
                sys.exit(1)
        os.symlink(src_path / config, full_dest_path)
        print(f"    -* Linked {config}")


def main() -> None:
    src_path, dest_path, config_list = inquirer_questions()
    print(f"Linking {config_list} configs from {src_path} to {dest_path}")

    not_founded = check_configs_exist(src_path, config_list)
    if not_founded:
        print(f"Configs not found: {not_founded}")
        sys.exit(1)
    print("Configs found")

    link_configs(src_path, dest_path, config_list)
    print("DONE")


if __name__ == "__main__":
    print("Start")
    main()
