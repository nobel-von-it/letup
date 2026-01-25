#!/usr/bin/env python

import subprocess
import sys
from pathlib import Path

DEPS = ["fakeroot", "debugedit", "git", "make", "curl", "go"]

YAY_DIR = Path(__file__).parent.parent / "yay"
YAY_URL = "https://aur.archlinux.org/yay.git"

if YAY_DIR.exists():
    print("yay already installed")
    sys.exit(0)

_ = subprocess.run(["sudo", "pacman", "-S", "--needed", *DEPS], check=True)
_ = subprocess.run(["git", "clone", YAY_URL, YAY_DIR], check=True)
_ = subprocess.run(["makepkg", "-si"], cwd=YAY_DIR, check=True)
