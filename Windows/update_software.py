import subprocess, os, sys, ctypes, logging, argparse, shutil, time, json
from dataclasses import dataclass, asdict
from datetime import datetime

DEFAULT_TIMEOUT = None  # Overridable via CLI
DEFAULT_RETRIES = 1


def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False


def run_as_admin():
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)


def _log_dir() -> str:
    base = os.getenv('LOCALAPPDATA') or os.getenv('TMP') or os.getcwd()
    return os.path.join(base, 'WindowsUpdateScript')


def setup_logging(level=logging.INFO):
    log_dir = _log_dir()
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f'update_log_{timestamp}.log')

    logging.getLogger().handlers.clear()
    logging.getLogger().setLevel(level)

    fmt = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    fh = logging.FileHandler(log_file, encoding='utf-8')
    fh.setFormatter(fmt)
    logging.getLogger().addHandler(fh)

    latest = os.path.join(log_dir, 'latest.log')
    try:
        lh = logging.FileHandler(latest, mode='w', encoding='utf-8')
        lh.setFormatter(fmt)
        logging.getLogger().addHandler(lh)
    except Exception:
        pass

    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    logging.getLogger().addHandler(sh)

    logging.info(f"Logs: {log_file}")
    return log_file


def powershell_exe() -> str:
    for candidate in ('pwsh', 'powershell'):
        if shutil.which(candidate):
            return candidate
    return 'powershell'


def run_command(command, ignore_errors=False, timeout: int | None = None, retries: int = 1, backoff: float = 2.0, shell: bool = False):
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
            out = (result.stdout or '').strip()
            err = (result.stderr or '').strip()
            cmd_str = command if isinstance(command, str) else ' '.join(command)
            if result.returncode == 0:
                logging.info(f"Command succeeded ({duration:.1f}s): {cmd_str}")
                return out
            else:
                msg = err or out
                logging.warning(f"Command failed rc={result.returncode} (try {attempt}/{retries}): {cmd_str} | {msg[:400]}")
                last_err = subprocess.CalledProcessError(result.returncode, command, output=out, stderr=err)
        except subprocess.TimeoutExpired as e:
            last_err = e
            cmd_str = command if isinstance(command, str) else ' '.join(command)
            logging.warning(f"Command timeout (try {attempt}/{retries}): {cmd_str}")
        if attempt < retries:
            sleep_for = backoff ** (attempt - 1)
            time.sleep(min(30, sleep_for))
    if ignore_errors:
        return None
    if last_err:
        raise last_err
    raise RuntimeError("Command failed with unknown error")


def run_powershell(ps_script, ignore_errors=False, timeout: int | None = None, retries: int = DEFAULT_RETRIES):
    exe = powershell_exe()
    return run_command([exe, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script], ignore_errors=ignore_errors, timeout=timeout, retries=retries)


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
    out = run_powershell(ps, ignore_errors=True, timeout=20)
    return isinstance(out, str) and out.strip().upper() == 'OK'


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
    # Ensure TLS 1.2 and robust NuGet provider bootstrap (avoids transient provider errors)
    run_powershell(
        "$ErrorActionPreference='SilentlyContinue';"
        "try { [Net.ServicePointManager]::SecurityProtocol = "
        "[Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls } catch {};"
        "try { if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) { "
        "Get-PackageProvider -Name NuGet -ForceBootstrap -Force | Out-Null } } catch {}",
        ignore_errors=True,
        timeout=180,
    )
    run_powershell("Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope AllUsers", ignore_errors=True, timeout=600)


def update_windows(skip_ms_update=False, timeout=None, retries=DEFAULT_RETRIES):
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


def update_winget_packages(include_msstore=True, timeout=None, retries=DEFAULT_RETRIES) -> int:
    if not command_exists('winget'):
        logging.info("Winget not found. Skipping.")
        return 0
    logging.info("Updating Winget sources and packages...")
    run_command(["winget", "source", "update"], ignore_errors=True, timeout=timeout, retries=retries)
    # Use `winget upgrade` to list available upgrades (modern CLI replaces `list --upgrades`)
    pre_list = run_command([
        "winget", "upgrade", "--include-unknown",
        "--accept-source-agreements", "--accept-package-agreements"
    ], ignore_errors=True, timeout=timeout, retries=1)
    pre_count = 0
    if pre_list:
        lines = [l for l in pre_list.splitlines() if l.strip() and not l.lower().startswith("name ")]
        pre_count = max(0, len(lines) - 1) if len(lines) > 1 else 0

    winget_args = [
        "winget", "upgrade", "--all", "--include-unknown",
        "--accept-source-agreements", "--accept-package-agreements"
    ]
    run_command(winget_args, ignore_errors=True, timeout=timeout, retries=retries)
    if include_msstore:
        logging.info("Updating Microsoft Store packages via winget (msstore source)...")
        run_command(["winget", "upgrade", "--source", "msstore", "--all",
                     "--accept-source-agreements", "--accept-package-agreements"], ignore_errors=True, timeout=timeout, retries=retries)
    return pre_count


def update_chocolatey_packages(timeout=None, retries=DEFAULT_RETRIES) -> int:
    if not is_chocolatey_installed():
        logging.info("Skipping Chocolatey updates (not installed).")
        return 0
    logging.info("Updating Chocolatey and all installed packages...")
    run_command(["choco", "upgrade", "chocolatey", "-y"], ignore_errors=True, timeout=timeout, retries=retries)
    out = run_command(["choco", "upgrade", "all", "-y"], ignore_errors=True, timeout=timeout, retries=retries)
    changed = 0
    if out:
        for line in out.splitlines():
            lo = line.lower()
            if (" upgraded " in lo) or (" installing " in lo) or (" upgrad" in lo and "packages upgraded" not in lo):
                changed += 1
    return changed


def is_chocolatey_installed():
    try:
        subprocess.run(["choco", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except Exception:
        logging.info("Chocolatey not found.")
        return False


def update_windows_store(timeout=None, retries=DEFAULT_RETRIES):
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
    ps = (
        "[bool]($null -ne (Get-Item 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired' -ErrorAction SilentlyContinue))"
        " -or [bool]($null -ne (Get-Item 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending' -ErrorAction SilentlyContinue))"
        " -or [bool]((Get-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations)"
    )
    out = run_powershell(ps, ignore_errors=True)
    needs_reboot = str(out).strip().lower().endswith('true') if out is not None else False
    logging.info(f"Reboot required: {needs_reboot}")
    return needs_reboot


def run_dism_health(timeout=None, retries=DEFAULT_RETRIES) -> PhaseResult:
    start = time.time()
    try:
        run_command(["Dism", "/Online", "/Cleanup-Image", "/RestoreHealth"], ignore_errors=False, timeout=timeout, retries=retries)
        dur = time.time() - start
        return PhaseResult(name="health_dism", success=True, skipped=False, changed=0, duration_sec=dur, details="DISM completed")
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(name="health_dism", success=False, skipped=False, changed=0, duration_sec=dur, error=str(e))


def run_sfc(timeout=None) -> PhaseResult:
    start = time.time()
    try:
        run_command(["sfc", "/scannow"], ignore_errors=False, timeout=timeout, retries=1)
        dur = time.time() - start
        return PhaseResult(name="health_sfc", success=True, skipped=False, changed=0, duration_sec=dur, details="SFC completed")
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(name="health_sfc", success=False, skipped=False, changed=0, duration_sec=dur, error=str(e))


def run_component_cleanup(aggressive=False, timeout=None) -> PhaseResult:
    start = time.time()
    args = ["Dism", "/Online", "/Cleanup-Image", "/StartComponentCleanup"]
    if aggressive:
        args.append("/ResetBase")
    try:
        run_command(args, ignore_errors=False, timeout=timeout, retries=1)
        dur = time.time() - start
        return PhaseResult(name="cleanup_components", success=True, skipped=False, changed=0, duration_sec=dur, details="Component cleanup completed")
    except Exception as e:
        dur = time.time() - start
        return PhaseResult(name="cleanup_components", success=False, skipped=False, changed=0, duration_sec=dur, error=str(e))


def run_updates_sequential(include_msstore=True, include_winupdate=True, include_winget=True, include_choco=True, timeout=None, retries=DEFAULT_RETRIES):
    results: list[PhaseResult] = []

    internet = check_internet()
    logging.info(f"Internet connectivity: {internet}")

    if include_winupdate and internet:
        prep_windows_update_module()
    elif include_winupdate and not internet:
        logging.warning("No internet: Windows Update may be limited or delayed.")

    if include_choco and is_chocolatey_installed():
        start = time.time()
        try:
            changed = update_chocolatey_packages(timeout=timeout, retries=retries)
            dur = time.time() - start
            results.append(PhaseResult("chocolatey", True, False, changed, dur, details=f"Packages changed: {changed}"))
        except Exception as e:
            dur = time.time() - start
            results.append(PhaseResult("chocolatey", False, False, 0, dur, error=str(e)))
    elif include_choco:
        results.append(PhaseResult("chocolatey", True, True, 0, 0.0, details="Chocolatey not installed"))

    if include_winget:
        start = time.time()
        try:
            changed = update_winget_packages(include_msstore=include_msstore, timeout=timeout, retries=retries)
            dur = time.time() - start
            results.append(PhaseResult("winget", True, False, changed, dur, details=f"Upgrades available before: {changed}"))
        except Exception as e:
            dur = time.time() - start
            results.append(PhaseResult("winget", False, False, 0, dur, error=str(e)))

    if include_msstore:
        start = time.time()
        try:
            update_windows_store(timeout=timeout, retries=retries)
            dur = time.time() - start
            results.append(PhaseResult("store", True, False, 0, dur, details="Store update triggered"))
        except Exception as e:
            dur = time.time() - start
            results.append(PhaseResult("store", False, False, 0, dur, error=str(e)))

    if include_winupdate:
        start = time.time()
        try:
            update_windows(timeout=max(timeout or 0, 7200), retries=retries)
            dur = time.time() - start
            results.append(PhaseResult("windows_update", True, False, 0, dur, details="Windows Update completed"))
        except Exception as e:
            dur = time.time() - start
            results.append(PhaseResult("windows_update", False, False, 0, dur, error=str(e)))
    else:
        results.append(PhaseResult("windows_update", True, True, 0, 0.0, details="Skipped by flag"))

    return results


def parse_args():
    parser = argparse.ArgumentParser(description="Comprehensive Windows updater: Winget, Chocolatey, Store, Windows Update, optional health + cleanup.")
    parser.add_argument("--reboot", action="store_true", help="Reboot automatically at the end if required.")
    parser.add_argument("--skip-store", action="store_true", help="Skip Microsoft Store updates.")
    parser.add_argument("--skip-winupdate", action="store_true", help="Skip Windows Update phase.")
    parser.add_argument("--skip-choco", action="store_true", help="Skip Chocolatey updates.")
    parser.add_argument("--skip-winget", action="store_true", help="Skip Winget updates.")
    parser.add_argument("--health", action="store_true", help="Run DISM and SFC health checks after updates.")
    parser.add_argument("--cleanup", action="store_true", help="Cleanup component store after updates (DISM StartComponentCleanup).")
    parser.add_argument("--aggressive-cleanup", action="store_true", help="Use DISM /ResetBase along with StartComponentCleanup.")
    parser.add_argument("--only", default="", help="Comma-separated phases to run: preflight,winget,choco,store,winupdate,health,cleanup")
    parser.add_argument("--timeout", type=int, default=0, help="Per-command timeout in seconds (0 = no timeout).")
    parser.add_argument("--retries", type=int, default=1, help="Retries for networked commands.")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"], help="Logging verbosity.")
    parser.add_argument("--summary-json", action="store_true", help="Write a JSON summary to the log directory.")
    return parser.parse_args()


def main():
    args = parse_args()

    log_file = setup_logging(level=getattr(logging, args.log_level))

    if not is_admin():
        logging.warning("Admin privileges required; attempting to elevate...")
        run_as_admin()
        sys.exit(0)

    logging.info("Software update initiated.")

    only_raw = [s.strip().lower() for s in args.only.split(',') if s.strip()] if args.only else []

    def want(phase: str, default=True):
        return (phase in only_raw) if only_raw else default

    timeout = args.timeout if args.timeout > 0 else None
    global DEFAULT_TIMEOUT, DEFAULT_RETRIES
    DEFAULT_TIMEOUT = timeout
    DEFAULT_RETRIES = max(1, args.retries)

    include_msstore = want('store', default=not args.skip_store)
    include_winupdate = want('winupdate', default=not args.skip_winupdate)
    include_winget = want('winget', default=not args.skip_winget)
    include_choco = want('choco', default=not args.skip_choco)

    results = run_updates_sequential(include_msstore=include_msstore,
                                     include_winupdate=include_winupdate,
                                     include_winget=include_winget,
                                     include_choco=include_choco,
                                     timeout=timeout,
                                     retries=DEFAULT_RETRIES)

    if want('health', default=args.health):
        logging.info("Running system health checks (DISM, SFC)...")
        results.append(run_dism_health(timeout=max(timeout or 0, 7200)))
        results.append(run_sfc(timeout=max(timeout or 0, 7200)))

    if want('cleanup', default=args.cleanup):
        logging.info("Cleaning up component store...")
        results.append(run_component_cleanup(aggressive=args.aggressive_cleanup, timeout=max(timeout or 0, 3600)))

    needs_reboot = check_reboot_required()
    if needs_reboot and args.reboot:
        logging.info("Reboot required and --reboot specified. Rebooting now...")
        try:
            subprocess.run(["shutdown", "/r", "/t", "5", "/c", "Rebooting after updates"], check=True)
        except subprocess.CalledProcessError:
            logging.error("Failed to initiate reboot. Please reboot manually.")
    elif needs_reboot:
        logging.warning("Reboot required to complete updates. Reboot when convenient.")
    else:
        logging.info("No reboot required.")

    logging.info("Software update completed.")

    summary = {
        'log_file': log_file,
        'needs_reboot': needs_reboot,
        'results': [asdict(r) for r in results],
        'finished_at': datetime.now().isoformat(),
    }
    logging.info("Summary:")
    for r in results:
        state = "SKIPPED" if r.skipped else ("OK" if r.success else "FAIL")
        logging.info(f" - {r.name}: {state} | changed={r.changed} | {r.duration_sec:.1f}s")
    if args.summary_json:
        try:
            out_path = os.path.join(_log_dir(), f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
            with open(out_path, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2)
            logging.info(f"Summary JSON: {out_path}")
        except Exception as e:
            logging.warning(f"Failed to write summary JSON: {e}")


if __name__ == "__main__":
    main()

