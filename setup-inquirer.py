#!/usr/bin/env python


import os
import shutil
import subprocess
import sys
from pathlib import Path

REAL_USER = os.getlogin()
YAY_SCRIPT_PATH = Path(__file__).parent / "setup-yay.py"

if os.geteuid() != 0:
    print("Please run this script as root.")
    os.execvp("sudo", ["sudo", "-E", sys.executable, *sys.argv])

if shutil.which("yay") is None and YAY_SCRIPT_PATH.exists():
    _ = subprocess.run([sys.executable, str(YAY_SCRIPT_PATH)], check=True)

sudoers_path = Path(f"/etc/sudoers.d/setup_temp_{REAL_USER}")
with open(sudoers_path, "w") as f:
    _ = f.write(f"{REAL_USER} ALL=(ALL) NOPASSWD: /usr/bin/pacman\n")

os.chmod(sudoers_path, 0o440)

try:
    _ = subprocess.run(
        [
            "sudo",
            "-u",
            REAL_USER,
            "yay",
            "-S",
            "--needed",
            "--noconfirm",
            "--noanswerclean",
            "--noanswerdiff",
            "--noansweredit",
            "--noanswerupgrade",
            "python-inquirer",
        ],
        check=True,
    )
finally:
    if sudoers_path.exists():
        sudoers_path.unlink()
