#!/usr/bin/env python

import os
import subprocess
import sys
from pathlib import Path

import inquirer


class DiskInfo:
    def __init__(self, uuid: str, fstype: str, mountpoint: str):
        self.uuid = uuid
        self.fstype = fstype
        self.mountpoint = mountpoint

    def short_uuid(self) -> str:
        return self.uuid.split("-")[0]


def check_sudo():
    if os.geteuid() != 0:
        print("Please run this script as root.")
        sys.exit(1)


def get_disks_info() -> list[DiskInfo]:
    SYSTEM_MOUNTPOINTS = {"/", "/boot", "/boot/efi", "[SWAP]"}

    out = subprocess.check_output(
        ["lsblk", "-o", "UUID,FSTYPE,MOUNTPOINT", "-n"], text=True
    )

    uuids: list[DiskInfo] = []

    for line in out.splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) < 2:
            continue

        uuid = parts[0]
        fstype = parts[1]
        mountpoint = parts[2] if len(parts) == 3 else ""

        if not uuid or fstype == "swap" or mountpoint in SYSTEM_MOUNTPOINTS:
            continue

        uuids.append(DiskInfo(uuid, fstype, mountpoint))

    return uuids


def inquirer_questions(disks_info: list[DiskInfo]) -> list[DiskInfo]:
    questions = [
        inquirer.Text(
            f"{di.short_uuid()}",
            message=f"Disk mountpoint for {di.short_uuid()}",
            default=di.mountpoint,
        )
        for di in disks_info
    ]
    if len(questions) != len(disks_info):
        print("inquirer error")
        sys.exit(1)

    answers = inquirer.prompt(questions)
    if answers is None:
        print("Aborted")
        sys.exit(1)

    mountpoins: list[str] = [str(v) for v in answers.values()]

    for di, new_mountpoint in zip(disks_info, mountpoins):
        if di.mountpoint != new_mountpoint:
            di.mountpoint = new_mountpoint

    return disks_info


def to_fstab(path: Path, di: DiskInfo) -> None:
    content = (
        f"\nUUID={di.uuid}  {di.mountpoint}  {di.fstype}  defaults,nofail,noatime 0 2\n"
    )
    with open(path, "a") as f:
        print(f"Writing to {path}: {content}")
        _ = f.write(content)


def main():
    fstab = Path("/etc/fstab")

    disks_info = get_disks_info()
    for di in inquirer_questions(disks_info):
        to_fstab(fstab, di)


if __name__ == "__main__":
    check_sudo()
    main()
