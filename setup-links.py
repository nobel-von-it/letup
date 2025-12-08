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
    "minvim:nvim",
    "fish",
    "zed",
    "tmux",
    "sway",
    "easyeffects",
]


def check_configs_exist(src_path: Path, config_list: list[str]) -> list[str]:
    not_founded: list[str] = []
    for config in config_list:
        print(f"  -* Checking {config}")
        orig_name = config.split(":")[0]
        if not (src_path / orig_name).exists():
            not_founded.append(orig_name)

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


def link_config(src_path: Path, dest_path: Path, config: str) -> None:
    names = config.split(":")

    orig_name, link_name = names if len(names) == 2 else (config, config)

    full_src_path = src_path / orig_name
    full_dest_path = dest_path / link_name
    print(f"  -* Checking {full_dest_path}")
    if full_dest_path.is_symlink():
        print(f"    -* Removing symlink {full_dest_path}")
        os.unlink(full_dest_path)
    elif full_dest_path.exists():
        print(f"    -* {full_dest_path} is not a symlink")
        print("Aborted")
        sys.exit(1)
    os.symlink(full_src_path, full_dest_path)
    print(f"    -* Linked {config}")


def tmux_config(src_path: Path, dest_path: Path) -> None:
    link_config(src_path, dest_path, "tmux")

    tpm_path = dest_path / "tmux/plugins/tpm"
    tpm_url = "https://github.com/tmux-plugins/tpm"
    if not tpm_path.exists():
        if os.system(f"git clone {tpm_url} {tpm_path}") != 0:
            print("Aborted by git clone for tpm")
            sys.exit(1)


def setup_configs(src_path: Path, dest_path: Path, configs: list[str]) -> None:
    for config in configs:
        if config == "tmux":
            tmux_config(src_path, dest_path)
        else:
            link_config(src_path, dest_path, config)


def main() -> None:
    src_path, dest_path, config_list = inquirer_questions()
    print(f"Linking {config_list} configs from {src_path} to {dest_path}")

    not_founded = check_configs_exist(src_path, config_list)
    if not_founded:
        print(f"Configs not found: {not_founded}")
        sys.exit(1)
    print("Configs found")

    setup_configs(src_path, dest_path, config_list)
    print("DONE")


if __name__ == "__main__":
    print("Start")
    main()
