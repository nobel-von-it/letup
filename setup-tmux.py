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
DEST_CONFIG_PATH = Path.home()

CONFIG_NAME = ".tmux.conf"

TPM_PATH = Path.home() / ".tmux/plugins/tpm"
TPM_URL = "https://github.com/tmux-plugins/tpm"


def check_config_exist(src_path: Path) -> bool:
    print(f"  -* Checking {CONFIG_NAME}")
    if src_path.name != "configs" and src_path.name.startswith(".tmux"):
        return src_path.exists()
    return (src_path / CONFIG_NAME).exists()


def inquirer_questions() -> tuple[Path, Path]:
    questions = [
        inquirer.Path("src", message="Source directory", default=SRC_CONFIG_PATH),
        inquirer.Path(
            "dest", message="Destination directory", default=DEST_CONFIG_PATH
        ),
    ]
    answers = inquirer.prompt(questions)
    if answers is None:
        print("Aborted")
        sys.exit(1)

    return (Path(answers["src"]), Path(answers["dest"]))


def main():
    if not check_config_exist(SRC_CONFIG_PATH):
        print("Configs not found")
        sys.exit(1)

    src_path, dest_path = inquirer_questions()
    print(f"Linking {CONFIG_NAME} from {src_path} to {dest_path}")

    full_src_path = src_path / CONFIG_NAME
    full_dest_path = dest_path / CONFIG_NAME
    print(f"  -* Checking {full_dest_path}")
    if full_dest_path.exists():
        if full_dest_path.is_symlink():
            print(f"    -* Removing symlink {full_dest_path}")
            os.unlink(full_dest_path)
        else:
            print(f"    -* {full_dest_path} is not a symlink")
            print("Aborted")
            sys.exit(1)
    os.symlink(full_src_path, full_dest_path)
    print(f"    -* Linked {CONFIG_NAME}")

    os.system(f"git clone --depth=1 {TPM_URL} {TPM_PATH}")
    os.system(f"{TPM_PATH}/bin/install_plugins")

    print("DONE")


if __name__ == "__main__":
    main()
