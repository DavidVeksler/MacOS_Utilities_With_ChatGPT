"""
Clean up common temp folders on Windows 10/11.

By default this script empties the current user's temp directories and
the system temp folder. It supports a dry-run mode and an age cutoff to
avoid deleting very recent files.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple


# Conservative defaults: user temp folders plus the system temp folder.
DEFAULT_TARGETS = (
    Path(os.environ.get("TEMP", "")),
    Path(os.environ.get("TMP", "")),
    Path(os.environ.get("LOCALAPPDATA", "")) / "Temp",
    Path(os.environ.get("SystemRoot", r"C:\Windows")) / "Temp",
)


@dataclass
class DeleteResult:
    deleted_files: int = 0
    deleted_dirs: int = 0
    failed: List[Tuple[Path, str]] | None = None

    def log_failure(self, path: Path, message: str) -> None:
        if self.failed is None:
            self.failed = []
        self.failed.append((path, message))


def iter_targets(custom_paths: Iterable[str] | None) -> List[Path]:
    if custom_paths:
        return [Path(p).expanduser() for p in custom_paths]
    # Filter out empty env vars while keeping order.
    return [p for p in DEFAULT_TARGETS if str(p).strip()]


def is_recent(path: Path, older_than_seconds: int | None, now: float) -> bool:
    if older_than_seconds is None:
        return False
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return False
    return (now - mtime) < older_than_seconds


def delete_path(path: Path, dry_run: bool, older_than_seconds: int | None, now: float, result: DeleteResult) -> None:
    # Skip symlinks to avoid following unexpected targets.
    if path.is_symlink():
        return
    if is_recent(path, older_than_seconds, now):
        return
    try:
        if dry_run:
            print(f"[DRY-RUN] Would delete: {path}")
            return
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=False)
            result.deleted_dirs += 1
        else:
            path.unlink()
            result.deleted_files += 1
    except FileNotFoundError:
        pass
    except PermissionError as exc:
        result.log_failure(path, f"Permission denied: {exc}")
    except OSError as exc:
        result.log_failure(path, f"Failed: {exc}")


def clean_directory(target: Path, dry_run: bool, older_than_seconds: int | None, result: DeleteResult) -> None:
    if not target.exists():
        return
    # Ensure we only clean inside the target, not the target itself.
    now = time.time()
    try:
        for entry in target.iterdir():
            delete_path(entry, dry_run, older_than_seconds, now, result)
    except PermissionError as exc:
        result.log_failure(target, f"Permission denied: {exc}")
    except OSError as exc:
        result.log_failure(target, f"Failed to enumerate: {exc}")


def format_failures(failed: List[Tuple[Path, str]] | None) -> str:
    if not failed:
        return ""
    lines = ["Failures:"]
    for path, message in failed:
        lines.append(f"  - {path}: {message}")
    return "\n".join(lines)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean up Windows temp folders safely.")
    parser.add_argument(
        "--path",
        action="append",
        help="Additional folder to clean. Can be passed multiple times. Defaults to common temp folders.",
    )
    parser.add_argument(
        "--older-than-days",
        type=float,
        default=0,
        help="Only delete items older than this many days. Defaults to 0 (delete regardless of age).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be removed without deleting anything.",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    older_than_seconds = None
    if args.older_than_days > 0:
        older_than_seconds = int(args.older_than_days * 86400)

    targets = iter_targets(args.path)
    if not targets:
        print("No targets to clean. Set TEMP/TMP or pass --path.", file=sys.stderr)
        return 1

    print("Targets:")
    for t in targets:
        print(f" - {t}")

    result = DeleteResult()
    for target in targets:
        clean_directory(target, args.dry_run, older_than_seconds, result)

    print("\nSummary:")
    print(f"Deleted files: {result.deleted_files}")
    print(f"Deleted directories: {result.deleted_dirs}")
    if result.failed:
        print(format_failures(result.failed))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
