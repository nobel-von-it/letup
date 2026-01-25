#!/usr/bin/env python


import shutil
import subprocess
import sys
from pathlib import Path

YAY_SCRIPT_PATH = Path(__file__).parent / "setup-yay.py"

if shutil.which("yay") is None and YAY_SCRIPT_PATH.exists():
    _ = subprocess.run([sys.executable, str(YAY_SCRIPT_PATH)], check=True)

_ = subprocess.run(["yay", "-S", "--needed", "python-inquirer"], check=True)
