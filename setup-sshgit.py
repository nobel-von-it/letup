#!/usr/bin/env python

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

INQUIRER_SCRIPT_PATH = Path(__file__).parent / "setup-inquirer.py"

try:
    import inquirer
except ImportError:
    _ = subprocess.run([INQUIRER_SCRIPT_PATH], check=True)
    import inquirer


DEPS = ["openssh"]

DEFAULT_EMAIL = "maksimdavydenko12@gmail.com"
DEFAULT_NAME = "nobel-von-it"
KEY_PATH = Path.home() / ".ssh/id_ed25519"

GITHUB_SSH_URL = "https://github.com/settings/ssh/new"
CODEBERG_SSH_URL = "https://codeberg.org/user/settings/keys"

_ = subprocess.run(["sudo", "pacman", "-S", "--needed", *DEPS], check=True)


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


def main() -> None:
    email, name = inquirer_questions()
    _ = subprocess.run(f"git config --global user.email {email}".split(" "), check=True)
    _ = subprocess.run(f"git config --global user.name {name}".split(" "), check=True)

    if not KEY_PATH.exists():
        KEY_PATH.parent.mkdir(parents=True, exist_ok=True)
        _ = subprocess.run(
            f'ssh-keygen -t ed25519 -f {KEY_PATH} -C {email} -N ""', check=True
        )

    res = subprocess.run(["ssh-agent", "-s"], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        match = re.match(r"(\w+)=([^;]+);", line)
        if match:
            os.environ[match.group(1)] = match.group(2)

    _ = subprocess.run(["ssh-add", KEY_PATH], check=True)

    pub_key = KEY_PATH.read_text()
    if shutil.which("wl-copy") is not None:
        _ = subprocess.run(["wl-copy", pub_key], check=True)

    print(f"Add this key to GitHub: {GITHUB_SSH_URL}")
    print(f"Add this key to Codeberg: {CODEBERG_SSH_URL}")

    print("Done")


if __name__ == "__main__":
    main()
