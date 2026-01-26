#!/usr/bin/env python

import os
import shutil
import subprocess
import sys
from pathlib import Path

DEPS = ["fakeroot", "debugedit", "git", "make", "curl", "go", "gcc"]

REAL_USER = os.getlogin()
YAY_DIR = Path(__file__).parent.parent / "yay"
YAY_URL = "https://aur.archlinux.org/yay.git"

if os.geteuid() != 0:
    print("Please run this script as root.")
    os.execvp("sudo", ["sudo", "-E", sys.executable, *sys.argv])

if shutil.which("yay") is not None:
    print("Yay is already installed.")
    sys.exit(0)


_ = subprocess.run(["pacman", "-S", "--needed", "--noconfirm", *DEPS], check=True)
if not YAY_DIR.exists():
    _ = subprocess.run(
        ["sudo", "-u", REAL_USER, "git", "clone", YAY_URL, YAY_DIR], check=True
    )


_ = subprocess.run(["sudo", "-u", REAL_USER, "makepkg", "-f"], cwd=YAY_DIR, check=True)
res = subprocess.run(
    ["sudo", "-u", REAL_USER, "makepkg", "--packagelist"],
    cwd=YAY_DIR,
    check=True,
    capture_output=True,
    text=True,
)
pkg_path = res.stdout.splitlines()

_ = subprocess.run(
    ["pacman", "-U", "--needed", "--noconfirm", *pkg_path],
    check=True,
)
