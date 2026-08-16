#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
import time
import argparse
from pathlib import Path
from datetime import datetime

# ANSI Colors for premium TUI
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'
    DARK_GRAY = '\033[90m'

# Icons for friendly visualization
class Icons:
    LOCK = "🔒"
    KEY = "🔑"
    SYNC = "🔄"
    TRASH = "🗑️"
    WARN = "⚠️"
    SUCCESS = "✅"
    INFO = "ℹ️"
    CROSS = "❌"
    ARROW = "➡️"
    SHIELD = "🛡️"

DEFAULT_MOUNT_POINT = "/mnt/vault"
USER_HOME = Path.home()

# Vault paths
TARGET_NAMES = ["gnupg", "ssh", "vault"]
LOCAL_TARGETS = {
    "gnupg": USER_HOME / ".gnupg",
    "ssh": USER_HOME / ".ssh",
    "vault": USER_HOME / ".vault"
}
BACKUP_TARGETS = {
    "gnupg": Path(DEFAULT_MOUNT_POINT) / ".gnupg",
    "ssh": Path(DEFAULT_MOUNT_POINT) / ".ssh",
    "vault": Path(DEFAULT_MOUNT_POINT)
}

LOCAL_TIMESTAMP_FILE = LOCAL_TARGETS["vault"] / ".last_backup"
BACKUP_TIMESTAMP_FILE = BACKUP_TARGETS["vault"] / ".last_backup"

# Excludes configuration for clean, safe syncing
GLOBAL_EXCLUDES = [
    "S.gpg-agent*",
    "S.scdaemon",
    "S.dirmngr",
    "gpg-agent.conf",
    "control",
    "random_seed",
    "*.tmp",
    "*.lock",
    "agent",
    "agent/*",
    "*.sock",
    "*.socket",
    ".stversions",
    ".stversions/**",
    ".stfolder",
    ".stfolder/**",
    ".sync-safety-backup",
    ".sync-safety-backup/**",
    ".last_backup"
]

VAULT_ROOT_EXCLUDES = [
    ".gnupg",
    ".gnupg/**",
    ".ssh",
    ".ssh/**",
    "lost+found",
    "lost+found/**",
    ".mount_write_test",
    ".vault"
]

def print_banner():
    banner = f"""
{Colors.HEADER}{Colors.BOLD}╔══════════════════════════════════════════════════════════╗
║                🔒 VAULT STORAGE MANAGER                  ║
║      Safeguarding, Syncing, and Wiping Your Secrets      ║
╚══════════════════════════════════════════════════════════╝{Colors.RESET}
"""
    print(banner)

def get_mount_point() -> Path:
    return Path(DEFAULT_MOUNT_POINT)

def is_drive_mounted() -> bool:
    """
    Checks if DEFAULT_MOUNT_POINT is actively mounted and writable by parsing /proc/mounts accurately.
    """
    mount_path = get_mount_point()
    target_str = str(mount_path.resolve())
    try:
        with open("/proc/mounts", "r") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 2 and parts[1] == target_str:
                    # Verify write permissions via a temporary test file
                    test_file = mount_path / ".mount_write_test"
                    try:
                        test_file.touch()
                        test_file.unlink()
                        return True
                    except (IOError, OSError):
                        return False
    except Exception:
        pass
    
    # Fallback to standard ismount check
    return os.path.ismount(str(mount_path)) and os.access(mount_path, os.W_OK)

def should_exclude(rel_path: Path, is_vault_root: bool = False) -> bool:
    """
    Checks if a relative path matches any exclude pattern.
    """
    for part in rel_path.parts:
        if part in ("agent", ".stfolder", ".stversions", ".sync-safety-backup"):
            return True
        if part.startswith("S.gpg-agent") or part in ("S.scdaemon", "S.dirmngr", "gpg-agent.conf", "control", "random_seed"):
            return True
        if part.endswith(".sock") or part.endswith(".socket") or part.endswith(".tmp") or part.endswith(".lock"):
            return True
        if part == ".last_backup":
            return True

    if is_vault_root and rel_path.parts:
        first_part = rel_path.parts[0]
        if first_part in (".gnupg", ".ssh", "lost+found", ".mount_write_test", ".vault"):
            return True

    return False

def scan_target_files(path: Path, is_vault_root: bool = False) -> dict[str, dict]:
    """
    Recursively scans a directory and returns a dictionary of relative paths with mtime and size.
    Avoids traversing excluded folders and symlink loops.
    """
    files_map = {}
    if not path.exists():
        return files_map

    for root, dirs, filenames in os.walk(path):
        root_path = Path(root)
        try:
            rel_dir = root_path.relative_to(path)
        except ValueError:
            rel_dir = Path(".")

        # Filter out directories to avoid traversing excludes and directory symlinks
        dirs[:] = [
            d for d in dirs
            if not should_exclude(rel_dir / d, is_vault_root) and not (root_path / d).is_symlink()
        ]

        for f in filenames:
            file_rel = rel_dir / f if rel_dir != Path(".") else Path(f)
            if should_exclude(file_rel, is_vault_root):
                continue
            fp = root_path / f
            try:
                stat = fp.stat() if not fp.is_symlink() else fp.lstat()
                files_map[str(file_rel)] = {
                    "mtime": stat.st_mtime,
                    "size": stat.st_size,
                    "is_symlink": fp.is_symlink(),
                    "abs_path": fp
                }
            except Exception:
                pass
    return files_map

def compare_targets_summary() -> dict[str, dict]:
    """
    Compares all targets between local and backup and returns a structured comparison.
    """
    mounted = is_drive_mounted()
    summary = {}
    for name in TARGET_NAMES:
        loc = scan_target_files(LOCAL_TARGETS[name], is_vault_root=False)
        bak = scan_target_files(BACKUP_TARGETS[name], is_vault_root=(name == "vault")) if mounted else {}
        
        all_keys = sorted(set(loc.keys()) | set(bak.keys()))
        local_only = []
        backup_only = []
        local_newer = []
        backup_newer = []
        identical = []

        for k in all_keys:
            if k in loc and k in bak:
                l_info = loc[k]
                b_info = bak[k]
                # Compare mtime with 1-second tolerance for filesystem differences
                if abs(l_info["mtime"] - b_info["mtime"]) < 1.0 and l_info["size"] == b_info["size"]:
                    identical.append(k)
                elif l_info["mtime"] > b_info["mtime"]:
                    local_newer.append((k, l_info, b_info))
                else:
                    backup_newer.append((k, l_info, b_info))
            elif k in loc:
                local_only.append((k, loc[k]))
            else:
                backup_only.append((k, bak[k]))

        summary[name] = {
            "local_only": local_only,
            "backup_only": backup_only,
            "local_newer": local_newer,
            "backup_newer": backup_newer,
            "identical": identical,
            "total_local": len(loc),
            "total_backup": len(bak)
        }
    return summary

def create_safety_backup(source_dir: Path, file_list: list[str], prefix: str = "safety-backup") -> Path | None:
    """
    Creates a timestamped safety backup of specified files before overwriting or deleting them.
    """
    if not file_list or not source_dir.exists():
        return None
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safety_root = source_dir / ".sync-safety-backup" / f"{prefix}_{timestamp}"
    backed_up_count = 0

    for rel_f in file_list:
        src_f = source_dir / rel_f
        if src_f.exists() and not src_f.is_symlink():
            dest_f = safety_root / rel_f
            dest_f.parent.mkdir(parents=True, exist_ok=True)
            try:
                if src_f.is_dir():
                    shutil.copytree(src_f, dest_f, symlinks=True)
                else:
                    shutil.copy2(src_f, dest_f)
                backed_up_count += 1
            except Exception:
                pass

    if backed_up_count > 0:
        print(f"  {Icons.SHIELD} {Colors.CYAN}Создана резервная копия безопасности ({backed_up_count} файлов) в:{Colors.RESET} {safety_root}")
        return safety_root
    return None

def check_ownership_and_permissions(fix_issues: bool = False):
    """
    Checks permissions of GPG, SSH, and Vault directories and files.
    Enforces drwx------ (0700) for directories and -rw------- (0600) for private keys.
    Prevents following recursive symlinks.
    """
    print(f"{Colors.BLUE}[Инфо]{Colors.RESET} Проверка владельца и прав доступа к файлам...")
    real_uid = os.getuid()
    issues_found = False

    for name, path in LOCAL_TARGETS.items():
        if not path.exists():
            continue

        # Check directory permissions (should be 0700)
        try:
            stat_info = path.stat()
            if stat_info.st_uid != real_uid:
                print(f"  {Icons.WARN} {Colors.YELLOW}Предупреждение:{Colors.RESET} Владелец директории {path} не совпадает с текущим пользователем!")
                issues_found = True
                if fix_issues:
                    try:
                        os.chown(path, real_uid, os.getgid())
                        print(f"    {Icons.SUCCESS} Владелец исправлен для {path}")
                    except Exception as e:
                        print(f"    {Icons.CROSS} Ошибка смены владельца: {e}")

            dir_mode = stat_info.st_mode & 0o777
            if dir_mode != 0o700:
                print(f"  {Icons.WARN} {Colors.YELLOW}Неверные права:{Colors.RESET} {path} имеет права {oct(dir_mode)} (ожидалось 0700)")
                issues_found = True
                if fix_issues:
                    try:
                        path.chmod(0o700)
                        print(f"    {Icons.SUCCESS} Права исправлены на 0700 для {path}")
                    except Exception as e:
                        print(f"    {Icons.CROSS} Ошибка исправления прав: {e}")
        except Exception:
            pass

        # Scan files inside GPG / SSH / Vault
        for root, dirs, files in os.walk(path):
            root_path = Path(root)

            # Enforce 0700 for subdirectories, skipping directory symlinks to avoid loops
            dirs[:] = [d for d in dirs if not (root_path / d).is_symlink() and d != ".sync-safety-backup"]
            for d in dirs:
                sub_d_path = root_path / d
                try:
                    sub_mode = sub_d_path.stat().st_mode & 0o777
                    if sub_mode != 0o700:
                        issues_found = True
                        if fix_issues:
                            sub_d_path.chmod(0o700)
                except Exception:
                    pass

            for f in files:
                file_path = root_path / f
                if file_path.is_symlink() or f == ".last_backup" or ".stfolder" in str(file_path):
                    continue

                # Determine expected permissions
                expected_mode = 0o600
                if f.endswith(".pub") or f in ("known_hosts", "known_hosts.old", "config"):
                    expected_mode = 0o644

                try:
                    f_stat = file_path.stat()
                    file_mode = f_stat.st_mode & 0o777
                    
                    is_sensitive = (
                        "private-keys" in str(file_path) or
                        "id_" in f or
                        f.endswith(".key") or
                        f.endswith(".sec") or
                        f.endswith(".kdbx") or
                        name == "vault"
                    )

                    if is_sensitive and file_mode != 0o600:
                        print(f"  {Icons.WARN} {Colors.YELLOW}Чувствительный файл:{Colors.RESET} {file_path.relative_to(USER_HOME)} имеет права {oct(file_mode)} (ожидалось 0600)")
                        issues_found = True
                        if fix_issues:
                            file_path.chmod(0o600)
                            print(f"    {Icons.SUCCESS} Права исправлены на 0600 для {file_path.name}")
                    elif not is_sensitive and file_mode not in (0o600, 0o644):
                        issues_found = True
                        if fix_issues:
                            file_path.chmod(expected_mode)
                except Exception:
                    pass

    if not issues_found:
        print(f"  {Icons.SUCCESS} {Colors.GREEN}Все права доступа и владельцы файлов в порядке!{Colors.RESET}")
    elif not fix_issues:
        print(f"  {Icons.INFO} {Colors.CYAN}Совет:{Colors.RESET} Запустите 'vault-manager status --fix' для автоматического исправления прав.")

def get_directory_size(path: Path) -> str:
    if not path.exists():
        return "Отсутствует"
    total_size = 0
    try:
        for root, dirs, files in os.walk(path):
            root_path = Path(root)
            if path == Path(DEFAULT_MOUNT_POINT):
                dirs[:] = [d for d in dirs if d not in (".gnupg", ".ssh", "lost+found", ".vault", ".sync-safety-backup")]
            else:
                dirs[:] = [d for d in dirs if d != ".sync-safety-backup"]
            for f in files:
                fp = root_path / f
                if not fp.is_symlink():
                    total_size += fp.stat().st_size
    except Exception:
        return "Недоступно"

    if total_size < 1024:
        return f"{total_size} B"
    elif total_size < 1024 * 1024:
        return f"{total_size / 1024:.1f} KB"
    else:
        return f"{total_size / (1024 * 1024):.1f} MB"

def get_last_backup_times() -> tuple[str, str]:
    """
    Returns timestamp strings for local and backup vault markers.
    """
    def format_ts(p: Path) -> str:
        if not p.exists():
            return "Никогда"
        try:
            val = float(p.read_text().strip())
            return datetime.fromtimestamp(val).strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            return "Неизвестно"

    return format_ts(LOCAL_TIMESTAMP_FILE), format_ts(BACKUP_TIMESTAMP_FILE)

def print_status():
    print_banner()
    mounted = is_drive_mounted()
    mount_status = f"{Colors.GREEN}Примонтирована ({DEFAULT_MOUNT_POINT}){Colors.RESET}" if mounted else f"{Colors.RED}Не примонтирована{Colors.RESET}"
    loc_ts, bak_ts = get_last_backup_times()
    
    print(f"{Colors.BOLD}Статус флешки-бэкапа:{Colors.RESET} {mount_status}")
    print(f"{Colors.BOLD}Маркер бэкапа (Локально):{Colors.RESET} {Colors.CYAN}{loc_ts}{Colors.RESET}")
    print(f"{Colors.BOLD}Маркер бэкапа (Флешка):{Colors.RESET}   {Colors.CYAN}{bak_ts}{Colors.RESET}")
    print()
    
    print(f"{Colors.BOLD}{'Компонент':<10} | {'Локальный размер':<18} | {'Бэкап размер':<15} | {'Статус синхронизации'}{Colors.RESET}")
    print("-" * 80)
    
    summary = compare_targets_summary()
    
    for name in TARGET_NAMES:
        loc_path = LOCAL_TARGETS[name]
        bak_path = BACKUP_TARGETS[name]
        
        loc_size = get_directory_size(loc_path)
        bak_size = get_directory_size(bak_path) if mounted else "—"
        
        if not mounted:
            status_text = f"{Colors.DARK_GRAY}Флешка отключена{Colors.RESET}"
        else:
            s = summary[name]
            if len(s["local_newer"]) > 0 or len(s["local_only"]) > 0:
                diff_count = len(s["local_newer"]) + len(s["local_only"])
                status_text = f"{Colors.YELLOW}🟡 Локально новее (+{diff_count} изм.){Colors.RESET}"
            elif len(s["backup_newer"]) > 0 or len(s["backup_only"]) > 0:
                diff_count = len(s["backup_newer"]) + len(s["backup_only"])
                status_text = f"{Colors.BLUE}🔵 Бэкап новее (+{diff_count} изм.){Colors.RESET}"
            else:
                status_text = f"{Colors.GREEN}🟢 Идентично{Colors.RESET}"
        
        print(f"{name.upper():<10} | {loc_size:<18} | {bak_size:<15} | {status_text}")
    print()
    
    check_ownership_and_permissions(fix_issues=False)

def secure_shred_file(file_path: Path):
    """
    Overwrites a file securely using 'shred' if available, otherwise native Python overwrite,
    then unlinks it.
    """
    if not file_path.is_file() or file_path.is_symlink():
        return

    # Check for shred in PATH
    shred_bin = shutil.which("shred")
    if shred_bin:
        try:
            # 3 passes, zero out, remove
            subprocess.run([shred_bin, "-u", "-z", "-n", "3", str(file_path)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except Exception:
            pass # Fall back to python method if shred fails

    # Native Python Secure Shredding
    try:
        file_size = file_path.stat().st_size
        if file_size > 0:
            with open(file_path, "r+b") as f:
                # Pass 1: Write random bytes
                f.seek(0)
                f.write(os.urandom(file_size))
                f.flush()
                os.fsync(f.fileno())

                # Pass 2: Write inverse bytes (0xFF)
                f.seek(0)
                f.write(b'\xff' * file_size)
                f.flush()
                os.fsync(f.fileno())

                # Pass 3: Write zeros (zeroing out)
                f.seek(0)
                f.write(b'\x00' * file_size)
                f.flush()
                os.fsync(f.fileno())

        # Truncate and remove
        file_path.unlink()
    except Exception as e:
        try:
            file_path.unlink()
        except Exception:
            print(f"  {Icons.CROSS} Не удалось удалить файл: {file_path} ({e})")

def secure_shred_directory(path: Path):
    """
    Recursively shreds all files in a directory and then removes all subdirectories.
    """
    if path.is_symlink():
        print(f"  {Icons.INFO} {Colors.CYAN}Удаление символической ссылки:{Colors.RESET} {path}")
        try:
            path.unlink()
            print(f"  {Icons.SUCCESS} Символическая ссылка {path} успешно удалена.")
        except Exception as e:
            print(f"  {Icons.CROSS} Ошибка при удалении символической ссылки {path}: {e}")
        return

    if path == Path(DEFAULT_MOUNT_POINT):
        print(f"{Colors.RED}[Шредер]{Colors.RESET} Запущен процесс безопасного уничтожения кастомных файлов на флешке...")
        file_count = 0
        for item in path.iterdir():
            if item.name in (".gnupg", ".ssh", "lost+found", ".mount_write_test", ".last_backup", ".vault", ".sync-safety-backup"):
                continue
            if item.is_symlink():
                item.unlink()
            elif item.is_dir():
                for root, dirs, files in os.walk(item, topdown=False):
                    root_path = Path(root)
                    for f in files:
                        file_path = root_path / f
                        secure_shred_file(file_path)
                        file_count += 1
                shutil.rmtree(item)
            else:
                secure_shred_file(item)
                file_count += 1
        print(f"  {Icons.SUCCESS} {Colors.GREEN}Безопасное уничтожение кастомных файлов на флешке завершено ({file_count} файлов)!{Colors.RESET}")
        return

    if not path.exists():
        return

    print(f"{Colors.RED}[Шредер]{Colors.RESET} Запущен процесс безопасного уничтожения в: {path}")
    file_count = 0
    for root, dirs, files in os.walk(path, topdown=False):
        root_path = Path(root)
        for f in files:
            file_path = root_path / f
            secure_shred_file(file_path)
            file_count += 1
            if file_count % 10 == 0:
                print(f"  {Icons.TRASH} Уничтожено {file_count} файлов...")

    try:
        shutil.rmtree(path)
    except Exception as e:
        print(f"  {Icons.CROSS} Ошибка при удалении папок в {path}: {e}")
        
    print(f"  {Icons.SUCCESS} {Colors.GREEN}Безопасное уничтожение завершено ({file_count} файлов)!{Colors.RESET}")

def clone_vault(direction: str, force: bool = False):
    """
    Clones folders from one side to another with conflict pre-check and safety backups.
    """
    mounted = is_drive_mounted()
    if not mounted:
        print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована или недоступна в {DEFAULT_MOUNT_POINT}!")
        sys.exit(1)

    summary = compare_targets_summary()

    if direction == "to-backup":
        local_exists = any(LOCAL_TARGETS[name].exists() for name in TARGET_NAMES)
        if not local_exists:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Локальные папки GPG/SSH/Vault отсутствуют! Нечего клонировать.")
            sys.exit(1)

        # Check if backup has newer data
        backup_newer_items = []
        for name in TARGET_NAMES:
            for k, l_info, b_info in summary[name]["backup_newer"]:
                backup_newer_items.append(f"{name}/{k} (Бэкап: {datetime.fromtimestamp(b_info['mtime'])} vs Локально: {datetime.fromtimestamp(l_info['mtime'])})")

        if backup_newer_items and not force:
            print(f"\n{Icons.WARN} {Colors.RED}{Colors.BOLD}ВНИМАНИЕ:{Colors.RESET} На флешке есть файлы, которые {Colors.BOLD}НОВЕЕ{Colors.RESET} локальных!")
            for item in backup_newer_items:
                print(f"  - {item}")
            confirm_override = input(f"\nВы уверены, что хотите перезаписать более свежие файлы на флешке? (yes/NO): ")
            if confirm_override.strip().lower() != 'yes':
                print("Клонирование отменено.")
                return

        print(f"{Icons.WARN} {Colors.RED}{Colors.BOLD}ВНИМАНИЕ:{Colors.RESET} Клонирование на флешку перезапишет данные бэкапа в {DEFAULT_MOUNT_POINT}!")
        confirm = input("Вы уверены, что хотите продолжить клонирование? (y/N): ")
        if confirm.lower() != 'y':
            print("Операция отменена.")
            return

        for name in TARGET_NAMES:
            loc = LOCAL_TARGETS[name]
            bak = BACKUP_TARGETS[name]
            if not loc.exists():
                continue
            
            print(f"  {Icons.SYNC} Клонирование {name} (Локально {Icons.ARROW} Флешка)...")
            if name == "vault":
                for item in loc.iterdir():
                    dest_item = bak / item.name
                    if should_exclude(Path(item.name), is_vault_root=True):
                        continue
                    if dest_item.is_symlink():
                        dest_item.unlink()
                    if dest_item.exists():
                        if dest_item.is_dir():
                            shutil.rmtree(dest_item)
                        else:
                            dest_item.unlink()
                            
                    if item.is_dir():
                        shutil.copytree(item, dest_item, symlinks=True)
                    else:
                        shutil.copy2(item, dest_item)
                print(f"    {Icons.SUCCESS} Содержимое vault успешно склонировано в корень флешки.")
            else:
                if bak.is_symlink():
                    try:
                        bak.unlink()
                    except Exception as e:
                        print(f"    {Icons.CROSS} {Colors.RED}Ошибка удаления символической ссылки {bak}: {e}{Colors.RESET}")
                        sys.exit(1)
                        
                if bak.exists():
                    shutil.rmtree(bak)
                
                shutil.copytree(loc, bak, symlinks=True)
                print(f"    {Icons.SUCCESS} Клон {name} успешно создан на флешке.")
        
        update_backup_timestamp()
        if LOCAL_TARGETS["vault"].exists():
            try:
                shutil.copy2(LOCAL_TIMESTAMP_FILE, BACKUP_TIMESTAMP_FILE)
            except Exception:
                pass
        
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Клонирование на флешку успешно завершено!{Colors.RESET}")

    elif direction == "from-backup":
        backup_exists = any(BACKUP_TARGETS[name].exists() for name in TARGET_NAMES)
        if not backup_exists:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Папки бэкапа на флешке отсутствуют!")
            sys.exit(1)

        # Critical protection: Check if local files are newer
        local_newer_items = []
        local_only_items = []
        for name in TARGET_NAMES:
            for k, l_info, b_info in summary[name]["local_newer"]:
                local_newer_items.append(f"{name}/{k} (Локально: {datetime.fromtimestamp(l_info['mtime'])} vs Бэкап: {datetime.fromtimestamp(b_info['mtime'])})")
            for k, l_info in summary[name]["local_only"]:
                local_only_items.append(f"{name}/{k}")

        if (local_newer_items or local_only_items) and not force:
            print(f"\n{Icons.CROSS} {Colors.RED}{Colors.BOLD}ОШИБКА БЕЗОПАСНОСТИ: Локальные данные новее или содержат уникальные файлы!{Colors.RESET}")
            if local_newer_items:
                print(f"{Colors.YELLOW}Файлы, которые локально новее, чем на бэкапе:{Colors.RESET}")
                for item in local_newer_items:
                    print(f"  - {item}")
            if local_only_items:
                print(f"{Colors.YELLOW}Файлы, существующие ТОЛЬКО локально (будут удалены):{Colors.RESET}")
                for item in local_only_items[:10]:
                    print(f"  - {item}")
                if len(local_only_items) > 10:
                    print(f"  ... и еще {len(local_only_items) - 10} файлов.")
            
            print(f"\n{Colors.RED}Восстановление из бэкапа уничтожит эти свежие локальные данные!{Colors.RESET}")
            phrase = "OVERWRITE NEWER DATA"
            confirm_phrase = input(f"Чтобы принудительно восстановить бэкап, введите фразу '{Colors.BOLD}{phrase}{Colors.RESET}': ")
            if confirm_phrase != phrase:
                print("Восстановление отменено. Ваши локальные файлы в безопасности.")
                return

        # Perform restore with safety backup
        for name in TARGET_NAMES:
            loc = LOCAL_TARGETS[name]
            bak = BACKUP_TARGETS[name]
            if not bak.exists():
                continue
            
            print(f"  {Icons.SYNC} Восстановление {name} (Флешка {Icons.ARROW} Локально)...")
            
            # Create safety backup of local files prior to restore
            if loc.exists():
                all_loc_files = list(scan_target_files(loc).keys())
                create_safety_backup(LOCAL_TARGETS["vault"], all_loc_files, prefix=f"pre-restore-{name}")

            if name == "vault":
                loc.mkdir(parents=True, exist_ok=True)
                for item in bak.iterdir():
                    if should_exclude(Path(item.name), is_vault_root=True):
                        continue
                    
                    dest_item = loc / item.name
                    if dest_item.is_symlink():
                        dest_item.unlink()
                    if dest_item.exists():
                        if dest_item.is_dir():
                            shutil.rmtree(dest_item)
                        else:
                            dest_item.unlink()
                            
                    if item.is_dir():
                        shutil.copytree(item, dest_item, symlinks=True)
                    else:
                        shutil.copy2(item, dest_item)
                print(f"    {Icons.SUCCESS} Все папки/файлы из корня флешки успешно скопированы в {loc}.")
            else:
                if loc.is_symlink():
                    try:
                        loc.unlink()
                    except Exception as e:
                        print(f"    {Icons.CROSS} {Colors.RED}Ошибка удаления символической ссылки {loc}: {e}{Colors.RESET}")
                        sys.exit(1)
                        
                if loc.exists():
                    shutil.rmtree(loc)
                
                shutil.copytree(bak, loc, symlinks=True)
                print(f"    {Icons.SUCCESS} Компонент {name} успешно восстановлен.")

        check_ownership_and_permissions(fix_issues=True)
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Восстановление локального хранилища успешно завершено!{Colors.RESET}")

def update_backup_timestamp():
    """
    Writes the current timestamp to ~/.vault/.last_backup
    """
    LOCAL_TARGETS["vault"].mkdir(parents=True, exist_ok=True)
    try:
        LOCAL_TIMESTAMP_FILE.write_text(str(time.time()))
    except Exception as e:
        print(f"  {Icons.WARN} Ошибка обновления времени бэкапа: {e}")

def run_sync(direction: str, dry_run: bool, force: bool = False):
    """
    Uses optimized rsync with conflict detection, safety backups, and update guards.
    """
    mounted = is_drive_mounted()
    if not mounted:
        print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована в {DEFAULT_MOUNT_POINT}!")
        sys.exit(1)

    rsync_bin = shutil.which("rsync")
    if not rsync_bin:
        print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Утилита 'rsync' не найдена! Установите её через менеджер пакетов.")
        sys.exit(1)

    print_banner()
    mode_text = "СИМУЛЯЦИЯ (DRY RUN)" if dry_run else "ПРИМЕНЕНИЕ (APPLY)"
    print(f"{Colors.BOLD}Режим синхронизации:{Colors.RESET} {Colors.YELLOW}{mode_text}{Colors.RESET}")
    print(f"{Colors.BOLD}Направление:{Colors.RESET} {Colors.CYAN}{direction}{Colors.RESET}")
    print()

    # Pre-sync Conflict & Safety Check
    summary = compare_targets_summary()
    
    if direction == "backup-to-local":
        local_newer_items = []
        for name in TARGET_NAMES:
            for k, l_info, b_info in summary[name]["local_newer"]:
                local_newer_items.append(f"{name}/{k} (Локально: {datetime.fromtimestamp(l_info['mtime'])} vs Бэкап: {datetime.fromtimestamp(b_info['mtime'])})")
            for k, l_info in summary[name]["local_only"]:
                local_newer_items.append(f"{name}/{k} (Только локально)")

        if local_newer_items and not force:
            print(f"{Icons.WARN} {Colors.RED}{Colors.BOLD}ВНИМАНИЕ: ОБНАРУЖЕН КОНФЛИКТ ВЕРСИЙ!{Colors.RESET}")
            print(f"{Colors.YELLOW}Вы запросили 'backup-to-local', но локальные файлы НОВЕЕ данных на флешке:{Colors.RESET}")
            for item in local_newer_items[:10]:
                print(f"  - {item}")
            if len(local_newer_items) > 10:
                print(f"  ... и еще {len(local_newer_items) - 10} файлов.")
            print(f"\n{Colors.CYAN}Для безопасной передачи изменений с локального ПК на флешку используйте:{Colors.RESET}")
            print(f"  {Colors.BOLD}vault-manager sync --direction local-to-backup{Colors.RESET}")
            
            if not dry_run:
                confirm = input(f"\nВы действительно хотите перезаписать свежие локальные файлы старыми? (yes/NO): ")
                if confirm.strip().lower() != 'yes':
                    print("Синхронизация отменена.")
                    return

    # Prepare sync jobs
    sync_jobs = []
    
    for name in TARGET_NAMES:
        loc = LOCAL_TARGETS[name]
        bak = BACKUP_TARGETS[name]
        
        if direction == "local-to-backup" and not loc.exists():
            loc.mkdir(parents=True, exist_ok=True)
            
        if direction == "local-to-backup" and not bak.exists():
            bak.mkdir(parents=True, exist_ok=True)
            
        if direction == "backup-to-local" and not bak.exists():
            print(f"  {Icons.WARN} Директория бэкапа {name} отсутствует на флешке, пропускаем.")
            continue
            
        if direction == "backup-to-local" and not loc.exists():
            loc.mkdir(parents=True, exist_ok=True)

        excludes = list(GLOBAL_EXCLUDES)
        if name == "vault":
            excludes.extend(VAULT_ROOT_EXCLUDES)
        
        exclude_args = []
        for exc in excludes:
            exclude_args.extend(["--exclude", exc])

        if direction == "local-to-backup":
            source = str(loc) + "/"
            dest = str(bak) + "/"
            sync_jobs.append((name, source, dest, exclude_args + ["--delete", "--update"]))
        elif direction == "backup-to-local":
            source = str(bak) + "/"
            dest = str(loc) + "/"
            # By default protect newer local files with --update
            rsync_opts = ["--delete", "--update"] if not force else ["--delete"]
            sync_jobs.append((name, source, dest, exclude_args + rsync_opts))
        elif direction == "bidirectional":
            # Bidirectional sync:
            # 1. Update local from backup (only if backup is newer, no delete)
            # 2. Update backup from local (propagate updates and deletions)
            sync_jobs.append((f"{name} (Флешка -> Локально)", str(bak) + "/", str(loc) + "/", exclude_args + ["--update"]))
            sync_jobs.append((f"{name} (Локально -> Флешка)", str(loc) + "/", str(bak) + "/", exclude_args + ["--update", "--delete"]))

    # Enforce strict local permissions prior to syncing
    if direction in ("local-to-backup", "bidirectional") and not dry_run:
        check_ownership_and_permissions(fix_issues=True)

    changes_found = False
    
    for label, src, dst, extra_args in sync_jobs:
        print(f"⏳ Анализ изменений для {Colors.BOLD}{label}{Colors.RESET}...")
        
        cmd = [rsync_bin, "-av", "--dry-run", "--itemize-changes"]
        cmd.extend(extra_args)
        cmd.extend([src, dst])
        
        res = subprocess.run(cmd, capture_output=True, text=True)
        
        file_changes = []
        for line in res.stdout.splitlines():
            if not line.strip() or line.startswith("sending incremental") or line.startswith("sent ") or line.startswith("total size "):
                continue
            
            # Parse itemize-changes output
            if line.startswith("*deleting"):
                fname = line.replace("*deleting", "").strip()
                file_changes.append((Colors.RED + "DELETING (Удаление)" + Colors.RESET, fname))
            elif len(line) >= 11 and line[0] in ('>', 'c', '<', 'h', '.'):
                prefix = line[:11]
                fname = line[11:].strip()
                if not fname or fname == "." or fname.endswith("/"):
                    continue
                if prefix.startswith(">f+++++++++"):
                    file_changes.append((Colors.GREEN + "NEW FILE (Создание)" + Colors.RESET, fname))
                elif prefix.startswith(">f") or prefix.startswith("cL"):
                    file_changes.append((Colors.GREEN + "UPDATE (Контент)" + Colors.RESET, fname))
                elif ".p" in prefix:
                    file_changes.append((Colors.BLUE + "PERM (Права доступа)" + Colors.RESET, fname))
                elif ">d" in prefix or "cd" in prefix:
                    continue
                else:
                    file_changes.append((Colors.GREEN + "UPDATE" + Colors.RESET, fname))
            elif not line.endswith("/") and line != "./":
                file_changes.append((Colors.GREEN + "UPDATE" + Colors.RESET, line.strip()))

        if file_changes:
            changes_found = True
            print(f"\n{Icons.INFO} Найдены изменения для {Colors.BOLD}{label}{Colors.RESET}:")
            print(f"  {'Действие':<20} | {'Файл'}")
            print("  " + "-" * 75)
            for action, fname in file_changes[:15]:
                print(f"  {action:<20} | {fname}")
            if len(file_changes) > 15:
                print(f"  ... и еще {len(file_changes) - 15} изменений.")
            print()
        else:
            print(f"  {Icons.SUCCESS} Синхронизировано. Нет изменений.")

    if not changes_found:
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Хранилища локально и на бэкапе полностью синхронизированы!{Colors.RESET}")
        if direction in ("local-to-backup", "bidirectional") and not dry_run:
            update_backup_timestamp()
            try:
                shutil.copy2(LOCAL_TIMESTAMP_FILE, BACKUP_TIMESTAMP_FILE)
            except Exception:
                pass
        return

    # If dry-run, ask if they want to apply
    if dry_run:
        confirm = input(f"Хотите применить эти изменения на практике? ({Colors.BOLD}yes{Colors.RESET}/no): ")
        if confirm.strip().lower() != 'yes':
            print("Синхронизация отменена.")
            return

    # Apply changes with safety backup
    print(f"\n🚀 {Colors.GREEN}Запуск реальной синхронизации хранилищ...{Colors.RESET}\n")
    for label, src, dst, extra_args in sync_jobs:
        print(f"{Icons.SYNC} Синхронизируем {Colors.BOLD}{label}{Colors.RESET}...")
        
        dest_path = Path(dst.rstrip("/"))
        if dest_path.exists() and direction == "backup-to-local":
            create_safety_backup(LOCAL_TARGETS["vault"], list(scan_target_files(dest_path).keys()), prefix="pre-sync")

        cmd = [rsync_bin, "-av"]
        cmd.extend(extra_args)
        cmd.extend([src, dst])
        
        subprocess.run(cmd, stdout=subprocess.DEVNULL)
        print(f"  {Icons.SUCCESS} Готово!")

    # Fix permissions locally if backup-to-local or bidirectional
    if direction in ("backup-to-local", "bidirectional"):
        check_ownership_and_permissions(fix_issues=True)

    # Save backup timestamp locally and on backup
    if direction in ("local-to-backup", "bidirectional"):
        update_backup_timestamp()
        if LOCAL_TARGETS["vault"].exists() and BACKUP_TARGETS["vault"].exists():
            try:
                shutil.copy2(LOCAL_TIMESTAMP_FILE, BACKUP_TIMESTAMP_FILE)
            except Exception:
                pass

    print(f"\n{Icons.SUCCESS} {Colors.GREEN}Синхронизация успешно завершена!{Colors.RESET}")

def wipe_vault(target: str):
    """
    Securely deletes standard secret folders with multi-step validation.
    """
    targets_to_wipe = []
    
    if target == "local":
        targets_to_wipe = list(LOCAL_TARGETS.values())
        loc_desc = "ЛОКАЛЬНОГО компьютера (~/.gnupg, ~/.ssh, ~/.vault)"
    elif target == "backup":
        if not is_drive_mounted():
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована! Невозможно уничтожить бэкап.")
            sys.exit(1)
        targets_to_wipe = list(BACKUP_TARGETS.values())
        loc_desc = "ФЛЕШКИ-БЭКАПА (/mnt/vault/...)"
    elif target == "both":
        if not is_drive_mounted():
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована! Подключите её, чтобы стереть обе копии.")
            sys.exit(1)
        targets_to_wipe = list(LOCAL_TARGETS.values()) + list(BACKUP_TARGETS.values())
        loc_desc = "ЛОКАЛЬНОГО компьютера И ФЛЕШКИ-БЭКАПА (ПОЛНОЕ УНИЧТОЖЕНИЕ)"
    else:
        print(f"{Icons.CROSS} Неверный выбор цели для уничтожения.")
        sys.exit(1)

    targets_to_wipe = [t for t in targets_to_wipe if t.exists()]
    if not targets_to_wipe:
        print(f"{Icons.SUCCESS} Цели для удаления пусты или отсутствуют.")
        return

    print(f"""
{Colors.RED}{Colors.BOLD}╔══════════════════════════════════════════════════════════╗
║             🚨 ОПАСНАЯ ОПЕРАЦИЯ: УНИЧТОЖЕНИЕ 🚨          ║
║   Вы собираетесь БЕЗОПАСНО УНИЧТОЖИТЬ ваши секреты из    ║
║   {loc_desc:<54} ║
║   Все данные будут многократно перезаписаны случайным    ║
║   шумом и нулями. Восстановление будет НЕВОЗМОЖНО!       ║
╚══════════════════════════════════════════════════════════╝{Colors.RESET}
""")

    print(f"{Colors.BOLD}Будут навсегда стерты следующие директории:{Colors.RESET}")
    for t in targets_to_wipe:
        print(f"  - {Colors.RED}{t}{Colors.RESET}")
    print()

    # Step 1 confirmation
    confirm1 = input("Вы действительно хотите полностью уничтожить эти секреты? (yes/NO): ")
    if confirm1.strip().lower() != 'yes':
        print("Операция отменена. Секреты в безопасности.")
        return

    # Step 2 confirmation - typing confirmation phrase
    phrase = "CONFIRM WIPE"
    confirm2 = input(f"Для подтверждения введите фразу '{Colors.BOLD}{phrase}{Colors.RESET}': ")
    if confirm2 != phrase:
        print("Фраза введена неверно. Операция немедленно отменена.")
        return

    # Step 3 confirmation - countdown
    print(f"\n{Colors.YELLOW}⚠️ ВНИМАНИЕ: Запуск уничтожения через 5 секунд... Нажмите Ctrl+C для отмены!{Colors.RESET}")
    for i in range(5, 0, -1):
        print(f"  {i}...")
        time.sleep(1)

    print(f"\n🔥 {Colors.RED}{Colors.BOLD}Уничтожение секретов...{Colors.RESET}")
    for t in targets_to_wipe:
        if t.exists():
            secure_shred_directory(t)

    if target in ("local", "both"):
        if LOCAL_TIMESTAMP_FILE.exists():
            try:
                LOCAL_TIMESTAMP_FILE.unlink()
            except Exception:
                pass

    print(f"\n{Icons.SUCCESS} {Colors.GREEN}Удаление успешно завершено! Все чувствительные следы стерты.{Colors.RESET}")

def main():
    parser = argparse.ArgumentParser(description="Менеджер хранилища секретов (GPG, SSH, custom Vault)")
    subparsers = parser.add_subparsers(dest="command", help="Команды")

    # Status command
    status_parser = subparsers.add_parser("status", help="Показать статус хранилищ и проверить права доступа")
    status_parser.add_argument("--fix", action="store_true", help="Автоматически исправить неверные права доступа")

    # Clone command
    clone_parser = subparsers.add_parser("clone", help="Инициализировать/восстановить хранилище")
    clone_parser.add_argument("--direction", choices=["to-backup", "from-backup"], required=True,
                               help="to-backup (клонировать локальное на флешку), from-backup (восстановить бэкап с флешки на ПК)")
    clone_parser.add_argument("--force", action="store_true", help="Принудительно перезаписать данные без проверки версий")

    # Sync command
    sync_parser = subparsers.add_parser("sync", help="Синхронизировать секреты с помощью rsync")
    sync_parser.add_argument("--direction", choices=["local-to-backup", "backup-to-local", "bidirectional"], default="local-to-backup",
                             help="Направление синхронизации (по умолчанию: local-to-backup)")
    sync_parser.add_argument("--apply", action="store_true", help="Применить изменения сразу без подтверждения")
    sync_parser.add_argument("--force", action="store_true", help="Игнорировать предупреждения о конфликтах версий")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Безопасно затереть (shred) хранилище")
    delete_parser.add_argument("--target", choices=["local", "backup", "both"], required=True,
                               help="local (стереть только на ПК), backup (стереть только на флешке), both (стереть везде)")

    args = parser.parse_args()

    if not args.command:
        print_status()
        sys.exit(0)

    try:
        if args.command == "status":
            if args.fix:
                check_ownership_and_permissions(fix_issues=True)
            else:
                print_status()
        elif args.command == "clone":
            clone_vault(args.direction, force=args.force)
        elif args.command == "sync":
            run_sync(args.direction, dry_run=not args.apply, force=args.force)
        elif args.command == "delete":
            wipe_vault(args.target)
    except KeyboardInterrupt:
        print(f"\n{Icons.CROSS} {Colors.RED}Операция принудительно прервана пользователем.{Colors.RESET}")
        sys.exit(130)

if __name__ == "__main__":
    main()
