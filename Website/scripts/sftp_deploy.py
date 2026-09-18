#!/usr/bin/env python3
"""Upload Website/dist to the Maverick group account home (web root)."""

from __future__ import annotations

import stat
from pathlib import Path

import paramiko

ROOT = Path(__file__).resolve().parents[1]

# Always remove the mistaken nested public_html from earlier deploys.
EXTRA_CLEAN = {"public_html"}


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.is_file():
        raise SystemExit(f"Missing {path} — copy .env.example to .env")
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip("'\"")
    return env


def remote_join(remote_dir: str, rel: str) -> str:
    if remote_dir in ("", ".", "./"):
        return rel
    return f"{remote_dir.rstrip('/')}/{rel}"


def ensure_dir(sftp: paramiko.SFTPClient, path: str) -> None:
    if path in ("", ".", "./"):
        return
    parts = [p for p in path.strip("/").split("/") if p]
    cur = ""
    for part in parts:
        cur = f"{cur}/{part}" if cur else part
        try:
            sftp.stat(cur)
        except FileNotFoundError:
            sftp.mkdir(cur)


def remove_tree(sftp: paramiko.SFTPClient, path: str) -> None:
    try:
        entries = sftp.listdir_attr(path)
    except FileNotFoundError:
        return
    for entry in entries:
        remote = f"{path}/{entry.filename}"
        if stat.S_ISDIR(entry.st_mode):
            remove_tree(sftp, remote)
        else:
            try:
                sftp.remove(remote)
            except FileNotFoundError:
                pass
    try:
        sftp.rmdir(path)
    except (OSError, FileNotFoundError):
        pass


def clear_site_files(
    sftp: paramiko.SFTPClient, remote_dir: str, managed: set[str]
) -> None:
    list_path = "." if remote_dir in ("", ".", "./") else remote_dir
    try:
        entries = sftp.listdir_attr(list_path)
    except FileNotFoundError:
        return
    for entry in entries:
        if entry.filename not in managed:
            continue
        remote = remote_join(remote_dir, entry.filename)
        print(f"  removing old {remote}")
        if stat.S_ISDIR(entry.st_mode):
            remove_tree(sftp, remote)
        else:
            sftp.remove(remote)


def main() -> None:
    env = load_env(ROOT / ".env")
    host = env.get("MAVERICK_HOST", "maverick.eecs.ucf.edu")
    user = env["MAVERICK_USER"]
    password = env["MAVERICK_PASS"]
    # Group home is already the Apache docroot — deploy to "." not public_html.
    remote_dir = env.get("MAVERICK_DIR", ".")
    local_dist = ROOT / "dist"
    if not local_dist.is_dir():
        raise SystemExit(f"Missing {local_dist} — run npm run build first")

    managed = {p.name for p in local_dist.iterdir()} | EXTRA_CLEAN

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connecting to {user}@{host} ...")
    client.connect(hostname=host, username=user, password=password, timeout=30)
    sftp = client.open_sftp()

    if remote_dir not in ("", ".", "./"):
        ensure_dir(sftp, remote_dir)

    print(f"Clearing previous site files in {remote_dir}/ ...")
    clear_site_files(sftp, remote_dir, managed)

    uploaded = 0
    for local in sorted(local_dist.rglob("*")):
        rel = local.relative_to(local_dist).as_posix()
        remote = remote_join(remote_dir, rel)
        if local.is_dir():
            ensure_dir(sftp, remote)
            continue
        parent = "/".join(remote.split("/")[:-1])
        if parent:
            ensure_dir(sftp, parent)
        print(f"  {rel}")
        sftp.put(str(local), remote)
        uploaded += 1

    sftp.close()
    client.close()
    print(f"Uploaded {uploaded} files to {user}@{host}:{remote_dir}/")


if __name__ == "__main__":
    main()
