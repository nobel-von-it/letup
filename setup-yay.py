#!/usr/bin/env python

import shutil
import subprocess
import sys
from pathlib import Path

DEPS = ["fakeroot", "debugedit", "git", "make", "curl", "go", "gcc"]

YAY_DIR = Path(__file__).parent.parent / "yay"
YAY_URL = "https://aur.archlinux.org/yay.git"

if shutil.which("yay") is not None:
    print("Yay is already installed.")
    sys.exit(0)

_ = subprocess.run(["sudo", "pacman", "-S", "--needed", *DEPS], check=True)
if not YAY_DIR.exists():
    _ = subprocess.run(["git", "clone", YAY_URL, YAY_DIR], check=True)
_ = subprocess.run(["makepkg", "-si"], cwd=YAY_DIR, check=True)
