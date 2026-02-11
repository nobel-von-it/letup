#!/usr/bin/env python

import importlib
import os
import pwd
import re
import shutil
import subprocess
import sys
from pathlib import Path

REAL_USER = os.getlogin()
HOME_DIR = Path(os.path.expanduser(f"~{REAL_USER}"))

INQUIRER_SCRIPT_PATH = Path(__file__).parent / "setup-inquirer.py"

if os.geteuid() != 0:
    print("Please run this script as root.")
    os.execvp("sudo", ["sudo", "-E", sys.executable, *sys.argv])

try:
    import inquirer
except (ImportError, ModuleNotFoundError):
    _ = subprocess.run([sys.executable, str(INQUIRER_SCRIPT_PATH)], check=True)
    importlib.invalidate_caches()

    try:
        import setuptools._distutils as distutils

        sys.modules["distutils"] = distutils
    except ImportError:
        pass

    import inquirer

DEPS = ["openssh"]

DEFAULT_EMAIL = "maksimdavydenko12@gmail.com"
DEFAULT_NAME = "nobel-von-it"
KEY_PATH = HOME_DIR / ".ssh/id_ed25519"

KNOWN_HOSTS = [
    "github.com",
    "codeberg.org",
]
KNOWN_HOSTS_PATH = KEY_PATH.parent / "known_hosts"

GITHUB_SSH_URL = "https://github.com/settings/ssh/new"
CODEBERG_SSH_URL = "https://codeberg.org/user/settings/keys"

_ = subprocess.run(["pacman", "-S", "--needed", "--noconfirm", *DEPS], check=True)


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
    _ = subprocess.run(["git", "config", "--global", "user.email", email], check=True)
    _ = subprocess.run(["git", "config", "--global", "user.name", name], check=True)

    if not KEY_PATH.exists():
        KEY_PATH.parent.mkdir(parents=True, exist_ok=True)
        _ = subprocess.run(
            ["ssh-keygen", "-t", "ed25519", "-f", str(KEY_PATH), "-C", email, "-N", ""],
            check=True,
        )

    res = subprocess.run(
        [
            "ssh-keyscan",
            *KNOWN_HOSTS,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    with open(KNOWN_HOSTS_PATH, "a") as f:
        _ = f.write(res.stdout)

    res = subprocess.run(["ssh-agent", "-s"], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        match = re.match(r"(\w+)=([^;]+);", line)
        if match:
            os.environ[match.group(1)] = match.group(2)

    _ = subprocess.run(["ssh-add", str(KEY_PATH)], check=True)

    user_info = pwd.getpwnam(REAL_USER)
    uid = user_info.pw_uid
    gid = user_info.pw_gid

    # Список путей для смены владельца и прав
    ssh_dir = KEY_PATH.parent
    pub_key_path = KEY_PATH.with_suffix(".pub")

    # Смена владельца рекурсивно на папку .ssh
    for item in [ssh_dir, KEY_PATH, pub_key_path, KNOWN_HOSTS_PATH]:
        if item.exists():
            os.chown(item, uid, gid)

    # Установка прав (chmod)
    ssh_dir.chmod(0o700)           # drwx------
    KEY_PATH.chmod(0o600)          # -rw-------
    pub_key_path.chmod(0o644)      # -rw-r--r--
    KNOWN_HOSTS_PATH.chmod(0o644)  # -rw-r--r--

    pub_key = KEY_PATH.with_suffix(".pub").read_text()
    if shutil.which("wl-copy") is not None:
        _ = subprocess.run(["wl-copy"], input=pub_key, text=True, check=True)
    elif shutil.which("xclip") is not None:
        _ = subprocess.run(
            ["xclip", "-selection", "clipboard"], input=pub_key, check=True
        )
    else:
        print("Cannot copy public key. Please copy manually:" + pub_key)

    print(f"Add this key to GitHub: {GITHUB_SSH_URL}")
    print(f"Add this key to Codeberg: {CODEBERG_SSH_URL}")

    print("Done")


if __name__ == "__main__":
    main()
