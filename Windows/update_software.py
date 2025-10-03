import subprocess, os, sys, ctypes, logging, argparse
from datetime import datetime

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    # Relaunch the current script with elevated privileges
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)

def setup_logging(level=logging.INFO):
    log_dir = os.path.join(os.getenv('LOCALAPPDATA'), 'WindowsUpdateScript')
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, f'update_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    logging.basicConfig(level=level,
                        format='%(asctime)s - %(levelname)s - %(message)s',
                        handlers=[logging.FileHandler(log_file), logging.StreamHandler()])

def run_command(command, ignore_errors=False):
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        logging.info(f"Command succeeded: {' '.join(command)}")
        return result.stdout
    except subprocess.CalledProcessError as e:
        msg = e.stderr.strip() or e.stdout.strip()
        logging.error(f"Command failed ({e.returncode}): {' '.join(command)} | {msg}")
        if ignore_errors:
            return None
        raise

def run_powershell(ps_script, ignore_errors=False):
    return run_command(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script], ignore_errors=ignore_errors)

def prep_windows_update_module():
    logging.info("Preparing PSWindowsUpdate module and providers...")
    run_powershell("Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force", ignore_errors=True)
    # Install or update PSWindowsUpdate
    run_powershell("Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope AllUsers", ignore_errors=True)

def update_windows(skip_ms_update=False):
    logging.info("Applying Windows Updates (no reboot during process)...")
    # Use Get-WindowsUpdate for newer module versions; fallback to Install-WindowsUpdate if needed
    ps = (
        "$ErrorActionPreference='Continue';"
        "Import-Module PSWindowsUpdate -Force;"
        "try {"
        f"    Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot {'-MicrosoftUpdate' if not skip_ms_update else ''};"
        "} catch {"
        f"    Install-WindowsUpdate -Install -AcceptAll -IgnoreReboot {'-MicrosoftUpdate' if not skip_ms_update else ''};"
        "}"
    )
    return run_powershell(ps, ignore_errors=False)

def update_winget_packages(include_msstore=True):
    logging.info("Updating Winget sources and packages...")
    run_command(["winget", "source", "update"], ignore_errors=True)
    # Upgrade all packages including unknown, accept agreements, run silent where possible
    winget_args = [
        "winget", "upgrade", "--all", "--include-unknown",
        "--accept-source-agreements", "--accept-package-agreements"
    ]
    run_command(winget_args, ignore_errors=True)
    if include_msstore:
        logging.info("Updating Microsoft Store packages via winget (msstore source)...")
        run_command(["winget", "upgrade", "--source", "msstore", "--all",
                     "--accept-source-agreements", "--accept-package-agreements"], ignore_errors=True)

def update_chocolatey_packages():
    logging.info("Updating Chocolatey and all installed packages...")
    run_command(["choco", "upgrade", "chocolatey", "-y"], ignore_errors=True)
    return run_command(["choco", "upgrade", "all", "-y"], ignore_errors=True)

def is_chocolatey_installed():
    try:
        subprocess.run(["choco", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except Exception:
        logging.info("Chocolatey not found.")
        return False

def update_windows_store():
    logging.info("Updating Microsoft Store apps (PowerShell fallback)...")
    ps = (
        "$ProgressPreference='SilentlyContinue';"
        "try { Get-AppxPackage -AllUsers | ForEach-Object {"
        "  try { Update-AppxPackage -Package $_.PackageFullName -ErrorAction Stop } catch {}"
        "} } catch {}"
    )
    return run_powershell(ps, ignore_errors=True)

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

def run_updates_sequential(include_msstore=True, include_winupdate=True):
    # Phase 0: Prep
    prep_windows_update_module()

    # Phase 1: Package managers
    if is_chocolatey_installed():
        update_chocolatey_packages()
    else:
        logging.info("Skipping Chocolatey updates (not installed).")

    update_winget_packages(include_msstore=include_msstore)

    # Phase 2: Microsoft Store fallback (PowerShell)
    if include_msstore:
        update_windows_store()

    # Phase 3: Windows Update (no reboot during process)
    if include_winupdate:
        update_windows()
    else:
        logging.info("Skipping Windows Update as requested.")

def parse_args():
    parser = argparse.ArgumentParser(description="Update Windows, package managers, and Store apps without mid-process reboots.")
    parser.add_argument("--reboot", action="store_true", help="Reboot automatically at the end if required.")
    parser.add_argument("--skip-store", action="store_true", help="Skip Microsoft Store updates.")
    parser.add_argument("--skip-winupdate", action="store_true", help="Skip Windows Update phase.")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"], help="Logging verbosity.")
    return parser.parse_args()

def main():
    args = parse_args()

    # Setup logging early to capture elevation decision
    setup_logging(level=getattr(logging, args.log_level))

    if not is_admin():
        logging.warning("Admin privileges required; attempting to elevate...")
        run_as_admin()
        sys.exit(0)

    logging.info("Software update initiated.")

    run_updates_sequential(include_msstore=not args.skip_store, include_winupdate=not args.skip_winupdate)

    # Final reboot decision
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

if __name__ == "__main__":
    main()
