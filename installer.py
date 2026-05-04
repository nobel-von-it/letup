#!/usr/bin/env python3

import os
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import inquirer
    from inquirer.themes import GreenPassion
except ImportError:
    print("Please install inquirer: pip install inquirer")
    sys.exit(1)

# --- Configuration ---
BASE_DIR = Path(__file__).parent
DEPS_DIR = BASE_DIR / ".deps"
CONFIGS_SRC_DIR = BASE_DIR / "configs"
CONFIGS_DEST_DIR = Path.home() / ".config"
CONFIG_JSON_PATH = BASE_DIR / "installer_config.json"


class Installer:
    def __init__(self, config_path: Path):
        with open(config_path, "r") as f:
            self.config = json.load(f)
        self.selected_profile = None
        self.selected_items = []
        self.dry_run = False

    def get_all_packages(self):
        pacman_pkgs = set()
        yay_pkgs = set()

        deps_files = []
        # Add profile deps
        if self.selected_profile:
            deps_files.extend(self.selected_profile.get("deps", []))
        
        # Add component deps
        for item in self.selected_items:
            deps_files.extend(item.get("deps", []))

        for dep_file in deps_files:
            dep_path = DEPS_DIR / dep_file
            if not dep_path.exists():
                print(f"Warning: Dependency file {dep_file} not found at {dep_path}")
                continue
            
            with open(dep_path, "r") as f:
                pkgs = [line.strip() for line in f if line.strip() and not line.startswith("#")]
                if dep_file.endswith(".pacman.txt"):
                    pacman_pkgs.update(pkgs)
                elif dep_file.endswith(".mix.txt"):
                    yay_pkgs.update(pkgs)
                else:
                    # Default to pacman if unknown
                    pacman_pkgs.update(pkgs)

        return list(pacman_pkgs), list(yay_pkgs)

    def get_all_configs(self):
        configs = []
        for item in self.selected_items:
            configs.extend(item.get("configs", []))
        # Remove duplicates while preserving order
        return list(dict.fromkeys(configs))

    def link_config(self, config: str, hardlink: bool = False):
        names = config.split(":")
        orig_name, link_name = names if len(names) == 2 else (config, config)

        src = CONFIGS_SRC_DIR / orig_name
        dest = CONFIGS_DEST_DIR / link_name

        # Special cases for home-level configs (not in .config)
        if config.startswith("zsh") or config.startswith("clang"):
             # For zsh/.zshrc:.zshrc or clang/.clang-format:.clang-format
             if ":" in config:
                 dest = Path.home() / link_name

        print(f"  -> Linking {orig_name} to {dest}")
        if self.dry_run:
            return

        if dest.is_symlink():
            dest.unlink()
        elif dest.exists():
            if dest.is_dir():
                print(f"     ! {dest} exists and is a directory. Skipping to avoid data loss.")
                return
            else:
                print(f"     ! {dest} exists. Backing up to {dest}.bak")
                shutil.move(dest, str(dest) + ".bak")

        dest.parent.mkdir(parents=True, exist_ok=True)
        if hardlink and src.is_file():
            os.link(src, dest)
        else:
            os.symlink(src, dest)

    # --- Special Tasks ---
    def task_tmux(self):
        print("  -> Setting up Tmux TPM...")
        if self.dry_run: return
        tpm_path = Path.home() / ".config/tmux/plugins/tpm"
        if not tpm_path.exists():
            subprocess.run(["git", "clone", "--depth=1", "https://github.com/tmux-plugins/tpm", str(tpm_path)], check=False)

    def task_ohmyzsh(self):
        print("  -> Setting up OhMyZsh...")
        if self.dry_run: return
        if not (Path.home() / ".oh-my-zsh").exists():
            cmd = 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
            subprocess.run(cmd, shell=True, check=False)

    def task_obsidian(self):
        print("  -> Setting up Obsidian snippets & scripts...")
        if self.dry_run: return
        mo_path = os.getenv("MO_BASE_PATH")
        if not mo_path: return
        
        snippets_path = Path(mo_path) / ".obsidian/snippets"
        if snippets_path.exists():
            if snippets_path.is_symlink(): snippets_path.unlink()
            elif snippets_path.is_dir(): shutil.rmtree(snippets_path)
        
        self.link_config(f"obsidian/snippets:{Path(mo_path)}/.obsidian/snippets")
        # Hardlinks for scripts
        self.link_config(f"../mo-scripts/create-game-project.js:{Path(mo_path)}/Resources/Scripts/create-game-project.js", hardlink=True)
        self.link_config(f"../mo-scripts/create-project.js:{Path(mo_path)}/Resources/Scripts/create-project.js", hardlink=True)

    def task_zapret(self):
        print("  -> Setting up Zapret...")
        if self.dry_run: return
        zapret_url = "https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git"
        zapret_path = BASE_DIR.parent / "zapret-discord-youtube-linux"
        if not zapret_path.exists():
            subprocess.run(["git", "clone", "--depth=1", zapret_url, str(zapret_path)], check=True)
        
        # Configure and sudoers (simplified from setup-links.py)
        conf_env = zapret_path / "conf.env"
        if not conf_env.exists():
            with open(conf_env, "w") as f:
                f.write("strategy=general_alt2.bat\ninterface=wlan0\ngamefilter=true\n")
        
        main_script = zapret_path / "main_script.sh"
        sudoers_path = Path("/etc/sudoers.d/10_zapret")
        if not sudoers_path.exists():
            print("     ! Requesting sudo for zapret configuration...")
            content = f"{os.getlogin()} ALL=(ALL) NOPASSWD: {main_script.absolute()}\n"
            subprocess.run(["sudo", "tee", str(sudoers_path)], input=content.encode(), check=True, stdout=subprocess.PIPE)
            subprocess.run(["sudo", "chmod", "0440", str(sudoers_path)], check=True)

        self.link_config("zapret/zapret.service:systemd/user/zapret.service")
        subprocess.run(["systemctl", "--user", "enable", "--now", "zapret"], check=False)

    def run(self):
        # 1. Profile Selection
        profile_choices = [ (p["name"], p) for p in self.config["profiles"] ] + [("Skip Base Profile", None)]
        questions = [
            inquirer.List("profile", message="Select Hardware Profile", choices=profile_choices),
            inquirer.Confirm("dry_run", message="Dry run? (No changes will be made)", default=False)
        ]
        answers = inquirer.prompt(questions)
        if not answers: return
        
        self.selected_profile = answers["profile"]
        self.dry_run = answers["dry_run"]

        # 2. Component Selection
        component_choices = []
        for group in self.config["groups"]:
            component_choices.append(inquirer.Separator(f"=== {group['name']} ==="))
            for item in group["items"]:
                component_choices.append((item["name"], item))

        questions = [
            inquirer.Checkbox("items", message="Select components to install/link", choices=component_choices)
        ]
        answers = inquirer.prompt(questions)
        if not answers: return
        self.selected_items = answers["items"]

        # 3. Execution
        pacman_pkgs, yay_pkgs = self.get_all_packages()
        configs = self.get_all_configs()

        print("\n--- Summary ---")
        if self.selected_profile: print(f"Profile: {self.selected_profile['name']}")
        print(f"Packages (pacman): {len(pacman_pkgs)}")
        print(f"Packages (yay):    {len(yay_pkgs)}")
        print(f"Configs to link:   {len(configs)}")
        if self.dry_run: print("!!! DRY RUN MODE !!!")
        
        confirm = inquirer.prompt([inquirer.Confirm("go", message="Proceed with installation?", default=True)])
        if not confirm or not confirm["go"]: return

        # Install packages
        if pacman_pkgs:
            print("\n--- Installing Pacman Packages ---")
            if not self.dry_run:
                subprocess.run(["sudo", "pacman", "-S", "--needed"] + pacman_pkgs, check=True)
            else:
                print(f"DRY RUN: sudo pacman -S --needed {' '.join(pacman_pkgs)}")

        if yay_pkgs:
            print("\n--- Installing AUR Packages (yay) ---")
            if not self.dry_run:
                subprocess.run(["yay", "-S", "--needed"] + yay_pkgs, check=True)
            else:
                print(f"DRY RUN: yay -S --needed {' '.join(yay_pkgs)}")

        # Link configs
        if configs:
            print("\n--- Linking Configs ---")
            for cfg in configs:
                # Handle special functions
                if cfg == "tmux": self.task_tmux()
                elif cfg == "ohmyzsh": self.task_ohmyzsh()
                elif cfg == "obsidian": self.task_obsidian()
                elif cfg == "zapret": self.task_zapret()
                elif cfg == "zsh": self.link_config("zsh/.zshrc:.zshrc")
                elif cfg == "clang": self.link_config("clang/.clang-format:.clang-format")
                else: self.link_config(cfg)

        print("\nDONE!")


if __name__ == "__main__":
    installer = Installer(CONFIG_JSON_PATH)
    try:
        installer.run()
    except KeyboardInterrupt:
        print("\nAborted.")
        sys.exit(0)
