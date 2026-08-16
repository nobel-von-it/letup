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

TIMESTAMP_FILE = LOCAL_TARGETS["vault"] / ".last_backup"

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
    Checks if DEFAULT_MOUNT_POINT is actively mounted and writable.
    """
    mount_path = get_mount_point()
    # Check via /proc/mounts for full accuracy on Linux
    try:
        with open("/proc/mounts", "r") as f:
            mounts = f.read()
        if str(mount_path) in mounts:
            # Verify it is writable
            test_file = mount_path / ".mount_write_test"
            try:
                test_file.touch()
                test_file.unlink()
                return True
            except IOError:
                return False
    except Exception:
        pass
    
    # Fallback to standard ismount
    return os.path.ismount(str(mount_path)) and os.access(mount_path, os.W_OK)

def check_ownership_and_permissions(fix_issues: bool = False):
    """
    Checks permissions of GPG, SSH, and Vault directories and files.
    Enforces drwx------ (0700) for directories and -rw------- (0600) for private keys.
    """
    print(f"{Colors.BLUE}[Инфо]{Colors.RESET} Проверка владельца и прав доступа к файлам...")
    real_uid = os.getuid()
    issues_found = False

    for name, path in LOCAL_TARGETS.items():
        if not path.exists():
            continue

        # Check directory permissions (should be 0700)
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

        # Scan files inside GPG / SSH / Vault
        for root, dirs, files in os.walk(path):
            root_path = Path(root)
            # Enforce 0700 for subdirectories
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
                # Skip symlinks
                if file_path.is_symlink():
                    continue

                # Determine expected permissions
                # GPG private keys, SSH private keys, credentials are 0600
                # SSH public keys, configs can be 0644 or 0600
                expected_mode = 0o600
                if f.endswith(".pub") or f == "known_hosts" or f == "config":
                    expected_mode = 0o644

                try:
                    f_stat = file_path.stat()
                    file_mode = f_stat.st_mode & 0o777
                    
                    # For highly sensitive files, strictly enforce 0600
                    is_sensitive = (
                        "private-keys" in str(file_path) or
                        "id_" in f or
                        f.endswith(".key") or
                        f.endswith(".sec") or
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
            if path == Path(DEFAULT_MOUNT_POINT):
                dirs[:] = [d for d in dirs if d not in (".gnupg", ".ssh", "lost+found", ".vault")]
            for f in files:
                fp = Path(root) / f
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

def get_last_backup_time() -> str:
    if not TIMESTAMP_FILE.exists():
        return "Никогда"
    try:
        timestamp = float(TIMESTAMP_FILE.read_text().strip())
        dt = datetime.fromtimestamp(timestamp)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return "Неизвестно"

def print_status():
    print_banner()
    mounted = is_drive_mounted()
    mount_status = f"{Colors.GREEN}Примонтирована ({DEFAULT_MOUNT_POINT}){Colors.RESET}" if mounted else f"{Colors.RED}Не примонтирована{Colors.RESET}"
    
    print(f"{Colors.BOLD}Статус флешки-бэкапа:{Colors.RESET} {mount_status}")
    print(f"{Colors.BOLD}Последний бэкап:{Colors.RESET} {Colors.CYAN}{get_last_backup_time()}{Colors.RESET}")
    print()
    
    print(f"{Colors.BOLD}{'Компонент':<15} | {'Локальный путь':<35} | {'Локальный размер':<18} | {'Бэкап размер':<15}{Colors.RESET}")
    print("-" * 90)
    for name in TARGET_NAMES:
        loc_path = LOCAL_TARGETS[name]
        bak_path = BACKUP_TARGETS[name]
        
        loc_size = get_directory_size(loc_path)
        bak_size = get_directory_size(bak_path) if mounted else "—"
        
        display_path = f"~/{loc_path.relative_to(USER_HOME)}"
        print(f"{name.upper():<15} | {display_path:<35} | {loc_size:<18} | {bak_size:<15}")
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
        # Fallback to standard delete if shredding fails
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
            if item.name in (".gnupg", ".ssh", "lost+found", ".mount_write_test", ".last_backup", ".vault"):
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
    # Walk and shred files first
    for root, dirs, files in os.walk(path, topdown=False):
        root_path = Path(root)
        for f in files:
            file_path = root_path / f
            secure_shred_file(file_path)
            file_count += 1
            if file_count % 10 == 0:
                print(f"  {Icons.TRASH} Уничтожено {file_count} файлов...")

    # Now delete all empty directories safely
    try:
        shutil.rmtree(path)
    except Exception as e:
        print(f"  {Icons.CROSS} Ошибка при удалении папок в {path}: {e}")
        
    print(f"  {Icons.SUCCESS} {Colors.GREEN}Безопасное уничтожение завершено ({file_count} файлов)!{Colors.RESET}")
def clone_vault(direction: str):
    """
    Clones folders from one side to another. Useful for fresh setups.
    """
    mounted = is_drive_mounted()
    
    if direction == "to-backup":
        if not mounted:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована или недоступна в {DEFAULT_MOUNT_POINT}!")
            sys.exit(1)
        
        # Check if local folders exist
        local_exists = any(LOCAL_TARGETS[name].exists() for name in TARGET_NAMES)
        if not local_exists:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Локальные папки GPG/SSH/Vault отсутствуют! Нечего клонировать.")
            sys.exit(1)

        print(f"{Icons.WARN} {Colors.RED}{Colors.BOLD}ВНИМАНИЕ:{Colors.RESET} Клонирование на флешку ПЕРЕЗАПИШЕТ данные бэкапа в {DEFAULT_MOUNT_POINT}!")
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
                # Copy contents of ~/.vault directly to the root /mnt/vault
                for item in loc.iterdir():
                    dest_item = bak / item.name
                    if dest_item.name in (".gnupg", ".ssh", "lost+found", ".mount_write_test", ".vault"):
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
                    print(f"    {Icons.INFO} {Colors.CYAN}Удаление символической ссылки {bak} на флешке...{Colors.RESET}")
                    try:
                        bak.unlink()
                    except Exception as e:
                        print(f"    {Icons.CROSS} {Colors.RED}Ошибка удаления символической ссылки {bak}: {e}{Colors.RESET}")
                        sys.exit(1)
                        
                if bak.exists():
                    shutil.rmtree(bak)
                
                shutil.copytree(loc, bak, symlinks=True)
                print(f"    {Icons.SUCCESS} Клон {name} успешно создан на флешке.")
        
        # Update timestamp file locally and copy it to backup
        update_backup_timestamp()
        if LOCAL_TARGETS["vault"].exists():
            shutil.copy2(TIMESTAMP_FILE, BACKUP_TARGETS["vault"] / ".last_backup")
        
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Клонирование на флешку успешно завершено!{Colors.RESET}")

    elif direction == "from-backup":
        if not mounted:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Флешка-бэкап не примонтирована! Невозможно восстановить файлы.")
            sys.exit(1)

        # Check if backup exists
        backup_exists = any(BACKUP_TARGETS[name].exists() for name in TARGET_NAMES)
        if not backup_exists:
            print(f"{Icons.CROSS} {Colors.RED}Ошибка:{Colors.RESET} Папки бэкапа на флешке отсутствуют!")
            sys.exit(1)

        print(f"{Icons.WARN} {Colors.RED}{Colors.BOLD}КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ:{Colors.RESET} Восстановление из бэкапа ПОЛНОСТЬЮ перезапишет ваши локальные GPG, SSH и файлы Vault!")
        confirm = input("Вы действительно хотите полностью заменить локальные ключи версией с флешки? (y/N): ")
        if confirm.lower() != 'y':
            print("Восстановление отменено.")
            return

        # Perform restore
        for name in TARGET_NAMES:
            loc = LOCAL_TARGETS[name]
            bak = BACKUP_TARGETS[name]
            if not bak.exists():
                continue
            
            print(f"  {Icons.SYNC} Восстановление {name} (Флешка {Icons.ARROW} Локально)...")
            if name == "vault":
                loc.mkdir(parents=True, exist_ok=True)
                # Copy all custom items from /mnt/vault to ~/.vault
                for item in bak.iterdir():
                    if item.name in (".gnupg", ".ssh", "lost+found", ".mount_write_test", ".vault"):
                        continue
                    
                    dest_item = loc / item.name
                    if dest_item.is_symlink():
                        dest_item.unlink()
                    if dest_item.exists():
                        if dest_item.is_dir():
                            secure_shred_directory(dest_item)
                        else:
                            secure_shred_file(dest_item)
                            
                    if item.is_dir():
                        shutil.copytree(item, dest_item, symlinks=True)
                    else:
                        shutil.copy2(item, dest_item)
                print(f"    {Icons.SUCCESS} Все дополнительные папки/файлы из корня флешки успешно скопированы в {loc}.")
            else:
                if loc.is_symlink():
                    print(f"    {Icons.INFO} {Colors.CYAN}Удаление символической ссылки {loc} перед восстановлением...{Colors.RESET}")
                    try:
                        loc.unlink()
                    except Exception as e:
                        print(f"    {Icons.CROSS} {Colors.RED}Ошибка удаления символической ссылки {loc}: {e}{Colors.RESET}")
                        sys.exit(1)
                        
                if loc.exists():
                    # Securely shred local directory first
                    print(f"    {Icons.WARN} Безопасное уничтожение старых локальных файлов {name} перед восстановлением...")
                    secure_shred_directory(loc)
                
                shutil.copytree(bak, loc, symlinks=True)
                print(f"    {Icons.SUCCESS} Компонент {name} успешно восстановлен.")

        # Set correct permissions on local paths
        check_ownership_and_permissions(fix_issues=True)
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Восстановление локального хранилища успешно завершено!{Colors.RESET}")


def update_backup_timestamp():
    """
    Writes the current timestamp to ~/.vault/.last_backup
    """
    LOCAL_TARGETS["vault"].mkdir(parents=True, exist_ok=True)
    try:
        TIMESTAMP_FILE.write_text(str(time.time()))
    except Exception as e:
        print(f"  {Icons.WARN} Ошибка обновления времени бэкапа: {e}")

def run_sync(direction: str, dry_run: bool):
    """
    Uses optimized rsync to synchronize local and backup targets.
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

    # Define sources and destinations based on direction
    sync_jobs = []
    
    for name in TARGET_NAMES:
        loc = LOCAL_TARGETS[name]
        bak = BACKUP_TARGETS[name]
        
        # Ensure local directories are created if local-to-backup and they don't exist
        if direction == "local-to-backup" and not loc.exists():
            loc.mkdir(parents=True, exist_ok=True)
            
        # Ensure backup directories exist on backup drive
        if direction == "local-to-backup" and not bak.exists():
            bak.mkdir(parents=True, exist_ok=True)
            
        if direction == "backup-to-local" and not bak.exists():
            print(f"  {Icons.WARN} Директория бэкапа {name} отсутствует на флешке, пропускаем.")
            continue
            
        if direction == "backup-to-local" and not loc.exists():
            loc.mkdir(parents=True, exist_ok=True)

        # Standard rsync options:
        # -a (archive: preserves symlinks, permissions, times, group, owner, devices)
        # -v (verbose)
        # --delete (remove extraneous files on receiver)
        # --exclude (prevent lock files or sockets from copying)
        excludes = ["S.gpg-agent*", "S.scdaemon", "gpg-agent.conf", "control", "random_seed"]
        if name == "vault":
            excludes.extend([".gnupg", ".ssh", "lost+found", ".mount_write_test", ".vault"])
        
        exclude_args = []
        for exc in excludes:
            exclude_args.extend(["--exclude", exc])

        if direction == "local-to-backup":
            source = str(loc) + "/"
            dest = str(bak) + "/"
            sync_jobs.append((name, source, dest, exclude_args))
        elif direction == "backup-to-local":
            source = str(bak) + "/"
            dest = str(loc) + "/"
            sync_jobs.append((name, source, dest, exclude_args))
        elif direction == "bidirectional":
            # Bidirectional sync is performed in two steps:
            # 1. Sync from backup to local, but WITHOUT --delete (only update new/updated files locally)
            # 2. Sync from local to backup WITH --delete (propagate all local updates to backup)
            # This is a safe bidirectional setup that keeps both sides up-to-date.
            sync_jobs.append((f"{name} (Флешка -> Локально)", str(bak) + "/", str(loc) + "/", exclude_args + ["--update"]))
            sync_jobs.append((f"{name} (Локально -> Флешка)", str(loc) + "/", str(bak) + "/", exclude_args + ["--update", "--delete"]))

    # Enforce strict local permissions prior to syncing
    if direction in ("local-to-backup", "bidirectional") and not dry_run:
        check_ownership_and_permissions(fix_issues=True)

    changes_found = False
    
    for label, src, dst, excl in sync_jobs:
        print(f"⏳ Анализ изменений для {Colors.BOLD}{label}{Colors.RESET}...")
        
        # Dry run cmd to fetch change list
        cmd = [rsync_bin, "-av", "--dry-run"]
        if "--delete" in excl or "delete" in label.lower() or direction != "bidirectional":
            cmd.append("--delete")
            
        cmd.extend(excl)
        cmd.extend([src, dst])
        
        res = subprocess.run(cmd, capture_output=True, text=True)
        
        # Parse rsync verbose output for file list
        lines = res.stdout.splitlines()
        file_changes = []
        for line in lines:
            if not line.strip():
                continue
            if line.startswith("sending incremental file list"):
                continue
            if line.startswith("sent ") or line.startswith("total size "):
                continue
            if line.endswith("/") or line == "./": # skip directories themselves
                continue
            if "deleting" in line:
                file_changes.append((Colors.RED + "DELETING" + Colors.RESET, line.replace("deleting ", "")))
            else:
                file_changes.append((Colors.GREEN + "UPDATE" + Colors.RESET, line))

        if file_changes:
            changes_found = True
            print(f"\n{Icons.INFO} Найдены изменения для {Colors.BOLD}{label}{Colors.RESET}:")
            print(f"  {'Действие':<20} | {'Файл'}")
            print("  " + "-" * 75)
            for action, fname in file_changes[:15]: # Show top 15 changes
                print(f"  {action:<20} | {fname}")
            if len(file_changes) > 15:
                print(f"  ... и еще {len(file_changes) - 15} изменений.")
            print()
        else:
            print(f"  {Icons.SUCCESS} Синхронизировано. Нет изменений.")

    if not changes_found:
        print(f"\n{Icons.SUCCESS} {Colors.GREEN}Хранилища локально и на бэкапе полностью идентичны!{Colors.RESET}")
        if direction == "local-to-backup" and not dry_run:
            update_backup_timestamp()
        return

    # If dry-run, ask if they want to apply
    if dry_run:
        confirm = input(f"Хотите применить эти изменения на практике? ({Colors.BOLD}yes{Colors.RESET}/no): ")
        if confirm.strip().lower() != 'yes':
            print("Синхронизация отменена.")
            return
        dry_run = False

    # Apply changes
    print(f"\n🚀 {Colors.GREEN}Запуск реальной синхронизации хранилищ...{Colors.RESET}\n")
    for label, src, dst, excl in sync_jobs:
        print(f"{Icons.SYNC} Синхронизируем {Colors.BOLD}{label}{Colors.RESET}...")
        
        cmd = [rsync_bin, "-a", "-v"]
        if "--delete" in excl or "delete" in label.lower() or direction != "bidirectional":
            cmd.append("--delete")
            
        cmd.extend(excl)
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
                shutil.copy2(TIMESTAMP_FILE, BACKUP_TARGETS["vault"] / ".last_backup")
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

    # Filter out targets that don't exist
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

    # Clean up timestamp file if local was wiped
    if target in ("local", "both"):
        if TIMESTAMP_FILE.exists():
            try:
                TIMESTAMP_FILE.unlink()
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

    # Sync command
    sync_parser = subparsers.add_parser("sync", help="Синхронизировать секреты с помощью rsync")
    sync_parser.add_argument("--direction", choices=["local-to-backup", "backup-to-local", "bidirectional"], default="local-to-backup",
                             help="Направление синхронизации (по умолчанию: local-to-backup)")
    sync_parser.add_argument("--apply", action="store_true", help="Применить изменения сразу без подтверждения")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Безопасно затереть (shred) хранилище")
    delete_parser.add_argument("--target", choices=["local", "backup", "both"], required=True,
                               help="local (стереть только на ПК), backup (стереть только на флешке), both (стереть везде)")

    args = parser.parse_args()

    if not args.command:
        # Default behavior: run status if no command provided
        print_status()
        sys.exit(0)

    try:
        if args.command == "status":
            if args.fix:
                check_ownership_and_permissions(fix_issues=True)
            else:
                print_status()
        elif args.command == "clone":
            clone_vault(args.direction)
        elif args.command == "sync":
            run_sync(args.direction, dry_run=not args.apply)
        elif args.command == "delete":
            wipe_vault(args.target)
    except KeyboardInterrupt:
        print(f"\n{Icons.CROSS} {Colors.RED}Операция принудительно прервана пользователем.{Colors.RESET}")
        sys.exit(130)

if __name__ == "__main__":
    main()
