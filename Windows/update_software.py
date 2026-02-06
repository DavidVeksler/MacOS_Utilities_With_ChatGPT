import subprocess, os, sys, ctypes, logging, argparse, shutil, time, json, glob
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from dataclasses import dataclass, asdict
from datetime import datetime

RICH_AVAILABLE = False
try:
    from rich.console import Console
    from rich.logging import RichHandler
    from rich.status import Status
    from rich.table import Table

    RICH_AVAILABLE = True
except ImportError:
    pass

LOG_DIR_NAME = "WindowsUpdateScript"
MAX_LOG_FILES = 10
WINUPDATE_TIMEOUT = 7200
CLEANUP_TIMEOUT = 3600
NUGET_BOOTSTRAP_TIMEOUT = 180
PSWINDOWSUPDATE_INSTALL_TIMEOUT = 600
INTERNET_CHECK_TIMEOUT = 20
REBOOT_DELAY_SEC = 5
REBOOT_REG_PATHS = [
    r"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
    r"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
]
PENDING_RENAME_PATH = r"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"

DEFAULT_TIMEOUT = None  # Overridable via CLI
DEFAULT_RETRIES = 1

console = Console() if RICH_AVAILABLE else None


def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except (AttributeError, OSError):
        return False


def run_as_admin():
    result = ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, " ".join(sys.argv), None, 1
    )
    if result <= 32:
        logging.error(
            f"Failed to elevate privileges (ShellExecuteW returned {result}). "
            "UAC prompt may have been denied."
        )
        sys.exit(1)


def _log_dir() -> str:
    base = os.getenv("LOCALAPPDATA") or os.getenv("TMP") or os.getcwd()
    return os.path.join(base, LOG_DIR_NAME)


def setup_logging(level=logging.INFO):
    log_dir = _log_dir()
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"update_log_{timestamp}.log")

    logging.getLogger().handlers.clear()
    logging.getLogger().setLevel(level)

    fmt = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(fmt)
    logging.getLogger().addHandler(fh)

    latest = os.path.join(log_dir, "latest.log")
    try:
        lh = logging.FileHandler(latest, mode="w", encoding="utf-8")
        lh.setFormatter(fmt)
        logging.getLogger().addHandler(lh)
    except Exception:
        pass

    if RICH_AVAILABLE:
        rh = RichHandler(console=console, show_time=True, show_path=False)
        rh.setLevel(level)
        logging.getLogger().addHandler(rh)
    else:
        sh = logging.StreamHandler()
        sh.setFormatter(fmt)
        logging.getLogger().addHandler(sh)

    logging.info(f"Logs: {log_file}")

    _rotate_logs(log_dir)

    return log_file


def _rotate_logs(log_dir: str):
    pattern = os.path.join(log_dir, "update_log_*.log")
    log_files = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
    for old_log in log_files[MAX_LOG_FILES:]:
        try:
            os.remove(old_log)
            logging.debug(f"Rotated old log: {old_log}")
        except OSError:
            pass


@contextmanager
def phase_status(label: str):
    if RICH_AVAILABLE and console is not None:
        with console.status(f"[bold cyan]{label}...") as _status:
            yield _status
    else:
        logging.info(f"Running {label}...")
        yield None


def powershell_exe() -> str:
    for candidate in ("pwsh", "powershell"):
        if shutil.which(candidate):
            return candidate
    return "powershell"


def run_command(
    command,
    ignore_errors=False,
    timeout: int | None = None,
    retries: int = 1,
    backoff: float = 2.0,
    shell: bool = False,
):
    attempt = 0
    last_err = None
    timeout = timeout if timeout and timeout > 0 else DEFAULT_TIMEOUT
    while attempt < max(1, retries):
        attempt += 1
        try:
            start = time.time()
            result = subprocess.run(
                command,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout,
                shell=shell,
            )
            duration = time.time() - start
            out = (result.stdout or "").strip()
            err = (result.stderr or "").strip()
            cmd_str = command if isinstance(command, str) else " ".join(command)
            if result.returncode == 0:
                logging.info(f"Command succeeded ({duration:.1f}s): {cmd_str}")
                return out
            else:
                msg = err or out
                logging.warning(
                    f"Command failed rc={result.returncode} (try {attempt}/{retries}): {cmd_str} | {msg[:400]}"
                )
                last_err = subprocess.CalledProcessError(
                    result.returncode, command, output=out, stderr=err
                )
        except subprocess.TimeoutExpired as e:
            last_err = e
            cmd_str = command if isinstance(command, str) else " ".join(command)
            logging.warning(f"Command timeout (try {attempt}/{retries}): {cmd_str}")
        if attempt < retries:
            sleep_for = backoff ** (attempt - 1)
            time.sleep(min(30, sleep_for))
    if ignore_errors:
        return None
    if last_err:
        raise last_err
    raise RuntimeError("Command failed with unknown error")


def run_powershell(
    ps_script,
    ignore_errors=False,
    timeout: int | None = None,
    retries: int = DEFAULT_RETRIES,
):
    exe = powershell_exe()
    return run_command(
        [exe, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
        ignore_errors=ignore_errors,
        timeout=timeout,
        retries=retries,
    )


def command_exists(program: str) -> bool:
    try:
        return shutil.which(program) is not None
    except Exception:
        return False


def check_internet() -> bool:
    ps = (
        "$ErrorActionPreference='SilentlyContinue';"
        "foreach ($t in @('one.one.one.one','8.8.8.8','www.microsoft.com')) {"
        "  if (Test-NetConnection -ComputerName $t -WarningAction SilentlyContinue -InformationLevel Quiet) { 'OK'; break }"
        "}"
    )
    out = run_powershell(ps, ignore_errors=True, timeout=INTERNET_CHECK_TIMEOUT)
    return isinstance(out, str) and out.strip().upper() == "OK"


@dataclass
class PhaseResult:
    name: str
    success: bool
    skipped: bool
    changed: int
    duration_sec: float
    details: str = ""
    error: str | None = None


def prep_windows_update_module():
    logging.info("Preparing PSWindowsUpdate module and providers...")
    run_powershell(
        "$ErrorActionPreference='SilentlyContinue';"
        "try { [Net.ServicePointManager]::SecurityProtocol = "
        "[Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls } catch {};"
        "try { if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) { "
        "Get-PackageProvider -Name NuGet -ForceBootstrap -Force | Out-Null } } catch {}",
        ignore_errors=True,
        timeout=NUGET_BOOTSTRAP_TIMEOUT,
    )
    run_powershell(
        "Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope AllUsers",
        ignore_errors=True,
        timeout=PSWINDOWSUPDATE_INSTALL_TIMEOUT,
    )


def _winget_upgrades_available(timeout: int | None, retries: int) -> tuple[int, list[str]]:
    """Return (count, package_names) of available winget upgrades.
    Tries JSON output first, falls back to text parsing."""
    # Try JSON output first
    try:
        json_out = run_command(
            [
                "winget", "upgrade",
                "--output", "json",
                "--include-unknown",
                "--accept-source-agreements",
                "--accept-package-agreements",
            ],
            ignore_errors=True,
            timeout=timeout,
            retries=1,
        )
        if json_out:
            data = json.loads(json_out)
            sources = data.get("Sources", [])
            packages = []
            for source in sources:
                for pkg in source.get("Packages", []):
                    name = pkg.get("PackageIdentifier", pkg.get("Name", "unknown"))
                    packages.append(name)
            return len(packages), packages
    except (json.JSONDecodeError, KeyError, TypeError):
        pass

    # Fallback: text parsing
    pre_list = run_command(
        [
            "winget", "upgrade", "--include-unknown",
            "--accept-source-agreements", "--accept-package-agreements",
        ],
        ignore_errors=True,
        timeout=timeout,
        retries=1,
    )
    if pre_list:
        lines = [
            l for l in pre_list.splitlines()
            if l.strip() and not l.lower().startswith("name ")
        ]
        count = max(0, len(lines) - 1) if len(lines) > 1 else 0
        return count, []
    return 0, []


def update_winget_packages(
    include_msstore=True,
    timeout=None,
    retries=DEFAULT_RETRIES,
    dry_run=False,
) -> int:
    if not command_exists("winget"):
        logging.info("Winget not found. Skipping.")
        return 0
    logging.info("Updating Winget sources and packages...")
    run_command(
        ["winget", "source", "update"],
        ignore_errors=True,
        timeout=timeout,
        retries=retries,
    )

    pre_count, packages = _winget_upgrades_available(timeout, retries)
    if packages:
        logging.info(f"Winget: {pre_count} upgrade(s) available: {', '.join(packages[:20])}")
    else:
        logging.info(f"Winget: {pre_count} upgrade(s) available")

    if dry_run:
        logging.info("[DRY RUN] Would run: winget upgrade --all")
        if include_msstore:
            logging.info("[DRY RUN] Would run: winget upgrade --source msstore --all")
        return pre_count

    if pre_count == 0:
        logging.info("All winget packages up to date. Skipping upgrade.")
    else:
        run_command(
            [
                "winget", "upgrade", "--all", "--include-unknown",
                "--accept-source-agreements", "--accept-package-agreements",
            ],
            ignore_errors=True,
            timeout=timeout,
            retries=retries,
        )

    if include_msstore:
        logging.info("Updating Microsoft Store packages via winget (msstore source)...")
        run_command(
            [
                "winget", "upgrade", "--source", "msstore", "--all",
                "--accept-source-agreements", "--accept-package-agreements",
            ],
            ignore_errors=True,
            timeout=timeout,
            retries=retries,
        )
    return pre_count


def update_chocolatey_packages(
    timeout=None, retries=DEFAULT_RETRIES, dry_run=False
) -> int:
    if not is_chocolatey_installed():
        logging.info("Skipping Chocolatey updates (not installed).")
        return 0

    # Check for outdated packages first
    outdated_out = run_command(
        ["choco", "outdated", "-r"], ignore_errors=True, timeout=timeout, retries=1
    )
    outdated_count = 0
    if outdated_out:
        outdated_lines = [l for l in outdated_out.splitlines() if l.strip()]
        outdated_count = len(outdated_lines)

    if dry_run:
        logging.info(f"[DRY RUN] Chocolatey: {outdated_count} outdated package(s)")
        if outdated_out:
            for line in outdated_out.splitlines()[:20]:
                logging.info(f"[DRY RUN]   {line}")
        return outdated_count

    if outdated_count == 0:
        logging.info("All Chocolatey packages up to date. Skipping upgrade.")
        return 0

    logging.info(f"Updating Chocolatey and {outdated_count} outdated package(s)...")
    run_command(
        ["choco", "upgrade", "chocolatey", "-y"],
        ignore_errors=True,
        timeout=timeout,
        retries=retries,
    )
    out = run_command(
        ["choco", "upgrade", "all", "-y"],
        ignore_errors=True,
        timeout=timeout,
        retries=retries,
    )
    changed = 0
    if out:
        for line in out.splitlines():
            lo = line.lower()
            if (
                (" upgraded " in lo)
                or (" installing " in lo)
                or (" upgrad" in lo and "packages upgraded" not in lo)
            ):
                changed += 1
    return changed


def is_chocolatey_installed():
    try:
        subprocess.run(
            ["choco", "--version"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return True
    except Exception:
        logging.info("Chocolatey not found.")
        return False


def update_windows(
    skip_ms_update=False,
    timeout=None,
    retries=DEFAULT_RETRIES,
    dry_run=False,
):
    if dry_run:
        logging.info("[DRY RUN] Would run: Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot")
        ps = (
            "$ErrorActionPreference='Continue';"
            "Import-Module PSWindowsUpdate -Force;"
            f"Get-WindowsUpdate {'-MicrosoftUpdate' if not skip_ms_update else ''};"
        )
        return run_powershell(ps, ignore_errors=True, timeout=timeout, retries=retries)

    logging.info("Applying Windows Updates (no reboot during process)...")
    ps = (
        "$ErrorActionPreference='Continue';"
        "Import-Module PSWindowsUpdate -Force;"
        "try {"
        f"    Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot {'-MicrosoftUpdate' if not skip_ms_update else ''};"
        "} catch {"
        f"    Install-WindowsUpdate -Install -AcceptAll -IgnoreReboot {'-MicrosoftUpdate' if not skip_ms_update else ''};"
        "}"
    )
    return run_powershell(ps, ignore_errors=False, timeout=timeout, retries=retries)


def update_windows_store(timeout=None, retries=DEFAULT_RETRIES, dry_run=False):
    if dry_run:
        logging.info("[DRY RUN] Would trigger Microsoft Store app updates")
        return None
    logging.info("Updating Microsoft Store apps (PowerShell fallback)...")
    ps = (
        "$ProgressPreference='SilentlyContinue';"
        "try { Get-AppxPackage -AllUsers | ForEach-Object {"
        "  try { Update-AppxPackage -Package $_.PackageFullName -ErrorAction Stop } catch {}"
        "} } catch {}"
    )
    return run_powershell(ps, ignore_errors=True, timeout=timeout, retries=retries)


def check_reboot_required():
    logging.info("Checking if a system reboot is required...")
    checks = " -or ".join(
        f"[bool]($null -ne (Get-Item '{path}' -ErrorAction SilentlyContinue))"
        for path in REBOOT_REG_PATHS
    )
    pending = (
        f"[bool]((Get-ItemProperty -Path '{PENDING_RENAME_PATH}' "
        "-Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations)"
    )
    ps = f"{checks} -or {pending}"
    out = run_powershell(ps, ignore_errors=True)
    needs_reboot = (
        str(out).strip().lower().endswith("true") if out is not None else False
    )
    logging.info(f"Reboot required: {needs_reboot}")
    return needs_reboot


def run_dism_health(
    timeout=None, retries=DEFAULT_RETRIES, dry_run=False
) -> PhaseResult:
    if dry_run:
        logging.info("[DRY RUN] Would run: DISM /Online /Cleanup-Image /RestoreHealth")
        return PhaseResult(
            name="health_dism", success=True, skipped=True, changed=0,
            duration_sec=0.0, details="[DRY RUN] Skipped",
        )
    start = time.time()
    try:
        run_command(
            ["Dism", "/Online", "/Cleanup-Image", "/RestoreHealth"],
            ignore_errors=False,
            timeout=timeout,
            retries=retries,
        )
        dur = time.time() - start
        return PhaseResult(
            name="health_dism", success=True, skipped=False, changed=0,
            duration_sec=dur, details="DISM completed",
        )
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(
            name="health_dism", success=False, skipped=False, changed=0,
            duration_sec=dur, error=str(e),
        )


def run_sfc(timeout=None, dry_run=False) -> PhaseResult:
    if dry_run:
        logging.info("[DRY RUN] Would run: sfc /scannow")
        return PhaseResult(
            name="health_sfc", success=True, skipped=True, changed=0,
            duration_sec=0.0, details="[DRY RUN] Skipped",
        )
    start = time.time()
    try:
        run_command(
            ["sfc", "/scannow"], ignore_errors=False, timeout=timeout, retries=1
        )
        dur = time.time() - start
        return PhaseResult(
            name="health_sfc", success=True, skipped=False, changed=0,
            duration_sec=dur, details="SFC completed",
        )
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(
            name="health_sfc", success=False, skipped=False, changed=0,
            duration_sec=dur, error=str(e),
        )


def run_component_cleanup(
    aggressive=False, timeout=None, dry_run=False
) -> PhaseResult:
    if dry_run:
        logging.info("[DRY RUN] Would run: DISM /Online /Cleanup-Image /StartComponentCleanup")
        return PhaseResult(
            name="cleanup_components", success=True, skipped=True, changed=0,
            duration_sec=0.0, details="[DRY RUN] Skipped",
        )
    start = time.time()
    args = ["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup"]
    if aggressive:
        args.append("/ResetBase")
    try:
        run_command(args, ignore_errors=False, timeout=timeout, retries=1)
        dur = time.time() - start
        return PhaseResult(
            name="cleanup_components", success=True, skipped=False, changed=0,
            duration_sec=dur, details="Component cleanup completed",
        )
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(
            name="cleanup_components", success=False, skipped=False, changed=0,
            duration_sec=dur, error=str(e),
        )


def _run_winget_phase(
    include_msstore, timeout, retries, dry_run
) -> PhaseResult:
    start = time.time()
    try:
        changed = update_winget_packages(
            include_msstore=include_msstore,
            timeout=timeout,
            retries=retries,
            dry_run=dry_run,
        )
        dur = time.time() - start
        return PhaseResult(
            "winget", True, False, changed, dur,
            details=f"Upgrades available: {changed}",
        )
    except Exception as e:
        dur = time.time() - start
        return PhaseResult("winget", False, False, 0, dur, error=str(e))


def _run_choco_phase(timeout, retries, dry_run) -> PhaseResult:
    start = time.time()
    try:
        changed = update_chocolatey_packages(
            timeout=timeout, retries=retries, dry_run=dry_run
        )
        dur = time.time() - start
        return PhaseResult(
            "chocolatey", True, False, changed, dur,
            details=f"Packages changed: {changed}",
        )
    except Exception as e:
        dur = time.time() - start
        return PhaseResult("chocolatey", False, False, 0, dur, error=str(e))


def run_updates(
    include_msstore=True,
    include_winupdate=True,
    include_winget=True,
    include_choco=True,
    timeout=None,
    retries=DEFAULT_RETRIES,
    dry_run=False,
    parallel=True,
):
    results: list[PhaseResult] = []

    internet = check_internet()
    logging.info(f"Internet connectivity: {internet}")

    if include_winupdate and internet:
        prep_windows_update_module()
    elif include_winupdate and not internet:
        logging.warning("No internet: Windows Update may be limited or delayed.")

    run_winget = include_winget
    choco_installed = is_chocolatey_installed() if include_choco else False
    run_choco = include_choco and choco_installed
    skip_choco_msg = include_choco and not choco_installed

    if parallel and run_winget and run_choco:
        label = "Updating winget and Chocolatey packages in parallel"
        with phase_status(label):
            with ThreadPoolExecutor(max_workers=2) as executor:
                futures = {}
                futures[executor.submit(
                    _run_winget_phase, include_msstore, timeout, retries, dry_run
                )] = "winget"
                futures[executor.submit(
                    _run_choco_phase, timeout, retries, dry_run
                )] = "choco"
                for future in as_completed(futures):
                    results.append(future.result())
    else:
        # Sequential fallback
        if run_choco:
            with phase_status("Updating Chocolatey packages"):
                results.append(_run_choco_phase(timeout, retries, dry_run))
        elif skip_choco_msg:
            results.append(
                PhaseResult(
                    "chocolatey", True, True, 0, 0.0,
                    details="Chocolatey not installed",
                )
            )

        if run_winget:
            with phase_status("Updating winget packages"):
                results.append(
                    _run_winget_phase(include_msstore, timeout, retries, dry_run)
                )

    if include_msstore:
        with phase_status("Updating Microsoft Store apps"):
            start = time.time()
            try:
                update_windows_store(timeout=timeout, retries=retries, dry_run=dry_run)
                dur = time.time() - start
                results.append(
                    PhaseResult(
                        "store", True, False, 0, dur,
                        details="Store update triggered",
                    )
                )
            except Exception as e:
                dur = time.time() - start
                results.append(PhaseResult("store", False, False, 0, dur, error=str(e)))

    if include_winupdate:
        with phase_status("Running Windows Update"):
            start = time.time()
            try:
                update_windows(
                    timeout=max(timeout or 0, WINUPDATE_TIMEOUT),
                    retries=retries,
                    dry_run=dry_run,
                )
                dur = time.time() - start
                results.append(
                    PhaseResult(
                        "windows_update", True, False, 0, dur,
                        details="Windows Update completed",
                    )
                )
            except Exception as e:
                dur = time.time() - start
                results.append(
                    PhaseResult("windows_update", False, False, 0, dur, error=str(e))
                )
    else:
        results.append(
            PhaseResult(
                "windows_update", True, True, 0, 0.0, details="Skipped by flag"
            )
        )

    return results


def _print_summary(results: list[PhaseResult], needs_reboot: bool, log_file: str):
    if RICH_AVAILABLE and console is not None:
        table = Table(title="Update Summary", show_lines=True)
        table.add_column("Phase", style="bold")
        table.add_column("Status")
        table.add_column("Changed", justify="right")
        table.add_column("Duration", justify="right")
        table.add_column("Details")
        for r in results:
            if r.skipped:
                status = "[dim]SKIPPED[/dim]"
            elif r.success:
                status = "[green]OK[/green]"
            else:
                status = "[red]FAIL[/red]"
            details = r.error or r.details or ""
            table.add_row(
                r.name,
                status,
                str(r.changed),
                f"{r.duration_sec:.1f}s",
                details[:80],
            )
        console.print(table)
        if needs_reboot:
            console.print("[bold yellow]Reboot required to complete updates.[/bold yellow]")
    else:
        logging.info("Summary:")
        for r in results:
            state = "SKIPPED" if r.skipped else ("OK" if r.success else "FAIL")
            logging.info(
                f" - {r.name}: {state} | changed={r.changed} | {r.duration_sec:.1f}s"
            )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Comprehensive Windows updater: Winget, Chocolatey, Store, Windows Update, optional health + cleanup."
    )
    parser.add_argument(
        "--reboot", action="store_true",
        help="Reboot automatically at the end if required.",
    )
    parser.add_argument(
        "--skip-store", action="store_true",
        help="Skip Microsoft Store updates.",
    )
    parser.add_argument(
        "--skip-winupdate", action="store_true",
        help="Skip Windows Update phase.",
    )
    parser.add_argument(
        "--skip-choco", action="store_true",
        help="Skip Chocolatey updates.",
    )
    parser.add_argument(
        "--skip-winget", action="store_true",
        help="Skip Winget updates.",
    )
    parser.add_argument(
        "--health", action="store_true",
        help="Run DISM and SFC health checks after updates.",
    )
    parser.add_argument(
        "--cleanup", action="store_true",
        help="Cleanup component store after updates (DISM StartComponentCleanup).",
    )
    parser.add_argument(
        "--aggressive-cleanup", action="store_true",
        help="Use DISM /ResetBase along with StartComponentCleanup.",
    )
    parser.add_argument(
        "--only", default="",
        help="Comma-separated phases to run: preflight,winget,choco,store,winupdate,health,cleanup",
    )
    parser.add_argument(
        "--timeout", type=int, default=0,
        help="Per-command timeout in seconds (0 = no timeout).",
    )
    parser.add_argument(
        "--retries", type=int, default=1,
        help="Retries for networked commands.",
    )
    parser.add_argument(
        "--log-level", default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging verbosity.",
    )
    parser.add_argument(
        "--summary-json", action="store_true",
        help="Write a JSON summary to the log directory.",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be updated without making changes.",
    )
    parser.add_argument(
        "--no-parallel", action="store_true",
        help="Disable parallel execution of winget and Chocolatey updates.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    log_file = setup_logging(level=getattr(logging, args.log_level))

    dry_run = args.dry_run
    if dry_run:
        logging.info("[DRY RUN] Dry-run mode enabled — no changes will be made.")

    if not is_admin():
        logging.warning("Admin privileges required; attempting to elevate...")
        run_as_admin()
        sys.exit(0)

    logging.info("Software update initiated.")

    only_raw = (
        [s.strip().lower() for s in args.only.split(",") if s.strip()]
        if args.only
        else []
    )

    def want(phase: str, default=True):
        return (phase in only_raw) if only_raw else default

    timeout = args.timeout if args.timeout > 0 else None
    global DEFAULT_TIMEOUT, DEFAULT_RETRIES
    DEFAULT_TIMEOUT = timeout
    DEFAULT_RETRIES = max(1, args.retries)

    include_msstore = want("store", default=not args.skip_store)
    include_winupdate = want("winupdate", default=not args.skip_winupdate)
    include_winget = want("winget", default=not args.skip_winget)
    include_choco = want("choco", default=not args.skip_choco)
    parallel = not args.no_parallel

    results = run_updates(
        include_msstore=include_msstore,
        include_winupdate=include_winupdate,
        include_winget=include_winget,
        include_choco=include_choco,
        timeout=timeout,
        retries=DEFAULT_RETRIES,
        dry_run=dry_run,
        parallel=parallel,
    )

    if want("health", default=args.health):
        with phase_status("Running DISM health check"):
            results.append(
                run_dism_health(
                    timeout=max(timeout or 0, WINUPDATE_TIMEOUT),
                    retries=DEFAULT_RETRIES,
                    dry_run=dry_run,
                )
            )
        with phase_status("Running SFC scan"):
            results.append(
                run_sfc(
                    timeout=max(timeout or 0, WINUPDATE_TIMEOUT),
                    dry_run=dry_run,
                )
            )

    if want("cleanup", default=args.cleanup):
        with phase_status("Cleaning up component store"):
            results.append(
                run_component_cleanup(
                    aggressive=args.aggressive_cleanup,
                    timeout=max(timeout or 0, CLEANUP_TIMEOUT),
                    dry_run=dry_run,
                )
            )

    needs_reboot = check_reboot_required()

    _print_summary(results, needs_reboot, log_file)

    if needs_reboot and args.reboot and not dry_run:
        logging.info("Reboot required and --reboot specified. Rebooting now...")
        try:
            subprocess.run(
                [
                    "shutdown", "/r", "/t", str(REBOOT_DELAY_SEC),
                    "/c", "Rebooting after updates",
                ],
                check=True,
            )
        except subprocess.CalledProcessError:
            logging.error("Failed to initiate reboot. Please reboot manually.")
    elif needs_reboot and args.reboot and dry_run:
        logging.info("[DRY RUN] Would reboot now.")
    elif needs_reboot:
        logging.warning(
            "Reboot required to complete updates. Reboot when convenient."
        )
    else:
        logging.info("No reboot required.")

    logging.info("Software update completed.")

    summary = {
        "log_file": log_file,
        "needs_reboot": needs_reboot,
        "dry_run": dry_run,
        "results": [asdict(r) for r in results],
        "finished_at": datetime.now().isoformat(),
    }
    if args.summary_json:
        try:
            out_path = os.path.join(
                _log_dir(),
                f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
            )
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(summary, f, indent=2)
            logging.info(f"Summary JSON: {out_path}")
        except Exception as e:
            logging.warning(f"Failed to write summary JSON: {e}")


if __name__ == "__main__":
    main()
