#!/usr/bin/env python

import argparse
import asyncio
import glob
import os
import shutil
import stat
from collections.abc import Coroutine
from typing import Any, cast

# --- CONFIGURATION ---

# Directory containing your custom config files (relative to this script).
# Expected format: dwm-config.def.h, st-config.def.h, etc.
CONFIGS_SRC_DIR = "./configs"
DIST_DEFAULT_DIR = "./.suckless-srcs"

# Target directory for user scripts
LOCAL_BIN_DIR = os.path.expanduser("~/.local/bin")

# List of programs: (path_on_server, version)
FILES = [
    ("dwm/dwm", "6.6"),
    ("tools/dmenu", "5.4"),
    ("st/st", "0.9.3"),
    ("tools/slock", "1.6"),
    ("tools/slstatus", "1.1"),
]

# List of patches: (tool_name, patch_url)
PATCHES = [
    ("st", "https://st.suckless.org/patches/anysize/st-anysize-0.8.4.diff"),
    ("st", "https://st.suckless.org/patches/clipboard/st-clipboard-0.8.3.diff"),
    ("dwm", "https://dwm.suckless.org/patches/ewmhtags/dwm-ewmhtags-6.2.diff"),
    (
        "dwm",
        "https://dwm.suckless.org/patches/focusonnetactive/dwm-focusonnetactive-6.2.diff",
    ),
]

# List of scripts to download: (category/name, url)
# These will be downloaded, chmod +x, and moved to ~/.local/bin/
SCRIPTS = [
    ("dmenu", "https://tools.suckless.org/dmenu/scripts/switch"),
    # Note: Ensure URLs point to the raw file, not an HTML page.
    # Added a valid example URL for demonstration:
    ("dmenu_websearch", "http://efe.kim/files/scripts/dmenu_websearch"),
]

# Additional dependencies to build from source
# Format: (name, type, url)
ADDITIONAL_DEPS = [
    ("wmctrl", "git", "https://github.com/dancor/wmctrl.git"),
]


def get_url(name: str, version: str) -> str:
    """Generates the download URL."""
    return f"https://dl.suckless.org/{name}-{version}.tar.gz"


async def download_chunked(url: str, name: str | None, dest_dir: str) -> str:
    """
    Async download using wget with interruptions.
    Returns the full path of the downloaded file.
    """
    filename = url.split("/")[-1]
    safe_name = name if name else filename
    full_path = os.path.join(dest_dir, filename)

    print(f"[{safe_name}] -> Starting download to: {full_path}")

    while True:
        # -c : continue getting a partially-downloaded file
        # -q : quiet mode
        # -O : output file
        cmd = ["wget", "-c", "-q", url, "-O", full_path]
        process = await asyncio.create_subprocess_exec(*cmd)

        try:
            # Wait for 2 seconds
            _ = await asyncio.wait_for(process.wait(), timeout=2)

            if process.returncode == 0:
                print(f"[{safe_name}] ✓ Done")
                break
            else:
                print(f"[{safe_name}] X Error (Exit code {process.returncode})")
                break

        except asyncio.TimeoutError:
            # Timeout triggered: interrupt and restart loop
            print(f"[{safe_name}] || Paused (2s timeout)...")
            process.terminate()

            try:
                _ = await process.wait()
            except:
                pass

    return full_path


def apply_patches(work_dir: str, tool_name: str) -> None:
    """Searches for .diff files in the directory and applies them."""
    diff_files = glob.glob(os.path.join(work_dir, "*.diff"))

    if not diff_files:
        return

    print(f"[{tool_name}] Applying patches...")
    for diff in diff_files:
        patch_name = os.path.basename(diff)
        cmd = f"cd {work_dir} && patch -p1 -N < {patch_name}"

        ret = os.system(cmd)
        if ret == 0:
            print(f"  [OK] Patch applied: {patch_name}")
        else:
            print(
                f"  [ERR] Failed to apply: {patch_name}. (May be incompatible or already applied)"
            )


def link_config(work_dir: str, tool_name: str) -> None:
    """Searches for {tool_name}-config.def.h in the configs folder and symlinks it."""
    custom_conf_name = f"{tool_name}-config.def.h"
    custom_conf_path = os.path.abspath(os.path.join(CONFIGS_SRC_DIR, custom_conf_name))
    target_conf = os.path.join(work_dir, "config.def.h")

    if os.path.exists(custom_conf_path):
        print(f"[{tool_name}] Found custom config: {custom_conf_name}")
        if os.path.exists(target_conf) or os.path.islink(target_conf):
            os.remove(target_conf)
        try:
            os.symlink(custom_conf_path, target_conf)
            print(f"  [LINK] Symlinked: config.def.h -> {custom_conf_name}")
        except OSError as e:
            print(f"  [ERR] Error creating symlink: {e}")
    else:
        print(
            f"[{tool_name}] Custom config not found ({custom_conf_path}), using default."
        )


def compile_and_install(work_dir: str, tool_name: str) -> None:
    """Executes 'sudo make install clean -B'."""
    print(f"[{tool_name}] Compiling and installing (sudo required)...")

    if tool_name == "dwm":
        print(f"[{tool_name}] Fixing Xutf8TextListToTextProperty types...")
        sed_cmd = (
            f"sed -i 's/Xutf8TextListToTextProperty(dpy, tags,/"
            f"Xutf8TextListToTextProperty(dpy, (char **)tags,/' {os.path.join(work_dir, 'dwm.c')}"
        )
        _ = os.system(sed_cmd)

    # -B : Always make unconditionally
    cmd = f"cd {work_dir} && sudo make install clean -B"
    ret = os.system(cmd)
    if ret == 0:
        print(f"[{tool_name}] ✓ Successfully installed.")
    else:
        print(f"[{tool_name}] X Compilation/Installation failed.")


def build_dependency(dest_dir: str, name: str, repo_url: str) -> None:
    """Clones a git repo and runs ./configure && make && sudo make install."""
    print(f"\n--- Processing Dependency: {name} ---")
    work_dir = os.path.join(dest_dir, name)

    # 1. Clone
    if not os.path.exists(work_dir):
        print(f"[{name}] Cloning {repo_url}...")
        ret = os.system(f"git clone {repo_url} {work_dir}")
        if ret != 0:
            print(f"[{name}] X Clone failed.")
            return
    else:
        print(f"[{name}] Directory exists, skipping clone.")

    # 2. Build Sequence
    print(f"[{name}] Building (configure -> make -> install)...")
    # Combining commands to ensure sequence stops on failure
    cmd = f"cd {work_dir} && ./configure && make && sudo make install"

    ret = os.system(cmd)
    if ret == 0:
        print(f"[{name}] ✓ Installed successfully.")
    else:
        print(f"[{name}] X Build failed.")


def install_local_scripts(script_src_dir: str) -> None:
    """Makes downloaded scripts executable and moves them to ~/.local/bin/."""
    print(f"\n--- Installing Scripts to {LOCAL_BIN_DIR} ---")

    if not os.path.exists(LOCAL_BIN_DIR):
        os.makedirs(LOCAL_BIN_DIR, exist_ok=True)

    # List files in the download temp folder
    for filename in os.listdir(script_src_dir):
        src_path = os.path.join(script_src_dir, filename)
        dest_path = os.path.join(LOCAL_BIN_DIR, filename)

        if os.path.isfile(src_path):
            try:
                # 1. chmod +x
                st = os.stat(src_path)
                os.chmod(src_path, st.st_mode | stat.S_IEXEC)

                # 2. Move (overwrite if exists)
                shutil.move(src_path, dest_path)
                print(f"  [INSTALLED] {filename}")
            except Exception as e:
                print(f"  [ERR] Failed to install {filename}: {e}")

    # Clean up temp script dir
    try:
        os.rmdir(script_src_dir)
    except:
        pass


async def main() -> None:
    parser = argparse.ArgumentParser(description="Suckless Auto-Builder")
    _ = parser.add_argument(
        "dest_dir", nargs="?", default=DIST_DEFAULT_DIR, help="Build directory"
    )
    args = parser.parse_args()
    dest_dir = cast(str, args.dest_dir)

    # Create working directory
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir, exist_ok=True)

    # === STEP 1: DOWNLOADING SOURCES ===
    print("\n=== [1/6] Downloading Sources ===")
    src_tasks: list[Coroutine[Any, Any, str]] = []  # pyright: ignore[reportExplicitAny]

    for name_path, version in FILES:
        url = get_url(name_path, version)
        short_name = name_path.split("/")[-1]
        task = download_chunked(url, f"SRC:{short_name}", dest_dir)
        src_tasks.append(task)

    if src_tasks:
        _ = await asyncio.gather(*src_tasks)

    # === STEP 2: EXTRACTION ===
    print("\n=== [2/6] Extracting Archives ===")
    extracted_dirs: list[tuple[str, str]] = []

    for file in os.listdir(dest_dir):
        if file.endswith(".tar.gz"):
            full_path = os.path.join(dest_dir, file)
            if os.system(f"tar xzf {full_path} -C {dest_dir}") == 0:
                os.remove(full_path)
            else:
                print(f"Error extracting {file}")

    for item in os.listdir(dest_dir):
        item_path = os.path.join(dest_dir, item)
        if os.path.isdir(item_path) and not item.startswith("."):
            # Filter out hidden dirs or dependency folders created later
            # Simple heuristic: suckless folders usually have '-' (st-0.9.2)
            if "-" in item:
                tool_name = item.split("-")[0]
                extracted_dirs.append((item, tool_name))

    # === STEP 3: DOWNLOADING PATCHES ===
    print("\n=== [3/6] Downloading Patches ===")
    patch_tasks: list[Coroutine[Any, Any, str]] = []  # pyright: ignore[reportExplicitAny]

    for tool_name, patch_url in PATCHES:
        target_folder = next((d[0] for d in extracted_dirs if d[1] == tool_name), None)
        if target_folder:
            target_path = os.path.join(dest_dir, target_folder)
            task = download_chunked(patch_url, f"PATCH:{tool_name}", target_path)
            patch_tasks.append(task)
        else:
            print(f"[SKIP] Directory for {tool_name} not found, skipping patch.")

    if patch_tasks:
        _ = await asyncio.gather(*patch_tasks)

    # === STEP 4: DOWNLOADING SCRIPTS ===
    print("\n=== [4/6] Downloading Scripts ===")
    # Create a temporary folder inside dest_dir for scripts
    scripts_tmp_dir = os.path.join(dest_dir, "scripts_tmp")
    os.makedirs(scripts_tmp_dir, exist_ok=True)

    script_tasks: list[Coroutine[Any, Any, str]] = []  # pyright: ignore[reportExplicitAny]

    for name, url in SCRIPTS:
        task = download_chunked(url, f"SCRIPT:{name}", scripts_tmp_dir)
        script_tasks.append(task)

    if script_tasks:
        _ = await asyncio.gather(*script_tasks)

    # === STEP 5: BUILDING DEPENDENCIES (Sync) ===
    # Done synchronously because of sudo usage and high resource usage
    print("\n=== [5/6] Building Dependencies ===")

    for name, dtype, url in ADDITIONAL_DEPS:
        if dtype == "git":
            build_dependency(dest_dir, name, url)

    # === STEP 6: INSTALLATION & COMPILATION ===
    print("\n=== [6/6] Finalizing Installation ===")

    # 1. Install Scripts
    install_local_scripts(scripts_tmp_dir)

    # 2. Build Suckless Tools
    extracted_dirs.sort()
    for folder_name, tool_name in extracted_dirs:
        full_work_dir = os.path.join(dest_dir, folder_name)
        print(f"\n--- Processing {tool_name} ({folder_name}) ---")
        apply_patches(full_work_dir, tool_name)
        link_config(full_work_dir, tool_name)
        compile_and_install(full_work_dir, tool_name)

    print("\n=== All operations completed ===")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
