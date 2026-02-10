#!/usr/bin/env python

import os
import shutil
import subprocess
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
    "ghostty",
    "kitty",
    "clang",
    "obsidian",
    "minvim:nvim",
    "fish",
    "zsh",
    "ohmyzsh",
    "zed",
    "tmux",
    "swaylock",
    "zapret",
    "sway",
    "niri",
    "waybar",
    "fuzzel",
    "mako",
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

    full_dest_path.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(full_src_path, full_dest_path)
    print(f"    -* Linked {config}")


def tmux_config(src_path: Path, dest_path: Path) -> None:
    link_config(src_path, dest_path, "tmux")

    tpm_path = dest_path / "tmux/plugins/tpm"
    tpm_url = "https://github.com/tmux-plugins/tpm"
    if not tpm_path.exists():
        try:
            _ = subprocess.run(
                ["git", "clone", "--depth=1", tpm_url, str(tpm_path)], check=True
            )
        except subprocess.CalledProcessError:
            print("Aborted by git clone for tpm")
            sys.exit(1)


def clang_config(src_path: Path) -> None:
    link_config(src_path, Path.home(), "clang/.clang-format:.clang-format")


def zsh_config(src_path: Path) -> None:
    link_config(src_path, Path.home(), "zsh/.zshrc:.zshrc")


def obsidian_config(src_path: Path, dest_path: Path) -> None:
    link_config(src_path, dest_path, "obsidian/obsidian.conf:obsidian.conf")

    mo_path = os.getenv("MO_BASE_PATH")
    if not mo_path:
        return
    snippets_path = Path(mo_path) / ".obsidian/snippets"
    if snippets_path.exists() and snippets_path.is_dir():
        if snippets_path.is_symlink():
            os.unlink(snippets_path)
        elif snippets_path.is_dir():
            shutil.rmtree(snippets_path)
    link_config(src_path, Path(mo_path), "obsidian/snippets:.obsidian/snippets")


def ohmyzsh_config() -> None:
    cmd = 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    try:
        _ = subprocess.run(cmd, shell=True, check=True)
    except subprocess.CalledProcessError:
        print("Failed to install Oh My Zsh")


def zapret_config(src_path: Path, dest_path: Path) -> None:
    zapret_url = "https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git"
    zapret_path = Path(__file__).parent.parent / "zapret"
    try:
        _ = subprocess.run(
            ["git", "clone", "--depth=1", zapret_url, zapret_path], check=True
        )
    except subprocess.CalledProcessError:
        print("Aborted by git clone for zapret")
        sys.exit(1)

    conf_env_path = zapret_path / "conf.env"
    with conf_env_path.open("a", encoding="utf-8") as f:
        # TODO: interaction
        f.write("strategy=general_alt2.bat\ninterface = wlan0\ngamefilter = true")
    main_script_path = zapret_path / "main_script.sh"

    try:
        new_sudoers_path = "/etc/sudoers.d/10_zapret"
        sudoers_zapret_content = (
            f"nimirus ALL=(ALL) NOPASSWD: {main_script_path.absolute()}"
        )
        _ = subprocess.run(
            ["sudo", "tee", new_sudoers_path],
            input=sudoers_zapret_content.encode("utf-8"),
            check=True,
            stdout=subprocess.PIPE,
        )
        _ = subprocess.run(["sudo", "chmod", "0440", new_sudoers_path], check=True)
    except subprocess.CalledProcessError:
        print("Aborted by tee or chmod zapret")
        sys.exit(1)

    link_config(
        src_path, dest_path, "zapret/zapret.service:systemd/user/zapret.service"
    )

    try:
        _ = subprocess.run(
            ["systemctl", "--user", "enable", "--now", "zapret"], check=True
        )
    except subprocess.CalledProcessError:
        print("Aborted by systemctl enable zapret")
        sys.exit(1)


def setup_configs(src_path: Path, dest_path: Path, configs: list[str]) -> None:
    for config in configs:
        if config == "tmux":
            tmux_config(src_path, dest_path)
        elif config == "clang":
            clang_config(src_path)
        elif config == "zsh":
            zsh_config(src_path)
        elif config == "ohmyzsh":
            ohmyzsh_config()
        elif config == "obsidian":
            obsidian_config(src_path, dest_path)
        elif config == "zapret":
            zapret_config(src_path, dest_path)
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
