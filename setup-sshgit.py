#!/usr/bin/env python

import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import inquirer
except ImportError:
    print("Please install inquirer")
    sys.exit(1)


DEFAULT_EMAIL = "maksimdavydenko12@gmail.com"
DEFAULT_NAME = "nobel-von-it"
KEY_PATH = Path.home() / ".ssh/id_ed25519.pub"

GITHUB_SSH_URL = "https://github.com/settings/ssh/new"
CODEBERG_SSH_URL = "https://codeberg.org/user/settings/keys"


def inquirer_questions() -> tuple[str, str]:
    questions = [
        inquirer.Text(
            "email",
            message="Email",
            default=DEFAULT_EMAIL,
        ),
        inquirer.Text(
            "name",
            message="Name",
            default=DEFAULT_NAME,
        ),
    ]
    answers = inquirer.prompt(questions)
    if answers is None:
        print("Aborted")
        sys.exit(1)

    return (answers["email"], answers["name"])


def ssh_eval():
    res = subprocess.run(["ssh-agent", "-s"], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        match = re.match(r"(\w+)=([^;]+);", line)
        if match:
            os.environ[match.group(1)] = match.group(2)


def exec(args: str, msg: str):
    res = subprocess.run(args.split(" "))
    if res.returncode != 0:
        print(msg)
        sys.exit(1)


def check_package(package: str) -> bool:
    res = subprocess.run(["command", "-v", package])
    return res.returncode == 0


def check_packages() -> list[str]:
    packages: list[str] = []
    if not check_package("git"):
        packages.append("git")
    if not check_package("ssh"):
        packages.append("openssh")
    if not check_package("wl-copy"):
        packages.append("wl-clipboard")
    return packages


def main() -> None:
    packages = check_packages()
    if packages:
        exec(
            f"sudo pacman -S --needed {' '.join(packages)}",
            "failed to install packages",
        )
    email, name = inquirer_questions()
    exec(f"git config --global user.email {email}", "failed to set email")
    exec(f"git config --global user.name {name}", "failed to set name")

    if not KEY_PATH.exists():
        exec(
            f"ssh-keygen -t ed25519 -f '{KEY_PATH}' -C '{email}'",
            "failed to generate ssh key",
        )

    ssh_eval()
    exec(
        f"ssh-add {KEY_PATH}",
        "failed to add ssh key",
    )

    pub_key = KEY_PATH.read_text()
    exec(f"wl-copy '{pub_key}'", "failed to copy key to clipboard")

    print(f"Add this key to GitHub: {GITHUB_SSH_URL}")
    print(f"Add this key to Codeberg: {CODEBERG_SSH_URL}")

    print("Done")


if __name__ == "__main__":
    main()
