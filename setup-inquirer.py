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


def yay_with_args(pkgs: list[str]) -> None:
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
            "--noasweredit",
            "--noanswerupgrade",
            *pkgs,
        ],
        check=True,
    )


if shutil.which("yay") is None and YAY_SCRIPT_PATH.exists():
    _ = subprocess.run([sys.executable, str(YAY_SCRIPT_PATH)], check=True)

yay_with_args(["python-inquirer"])
