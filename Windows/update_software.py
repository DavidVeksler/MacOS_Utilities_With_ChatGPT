import subprocess, os, sys, ctypes, logging
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)

def setup_logging():
    log_dir = os.path.join(os.getenv('LOCALAPPDATA'), 'WindowsUpdateScript')
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, f'update_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s',
                        handlers=[logging.FileHandler(log_file), logging.StreamHandler()])

def run_command(command):
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        logging.info(f"Command '{' '.join(command)}' executed successfully.")
        return result.stdout
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {' '.join(command)} | Error: {e.stderr}")
        return None

def update_windows():
    logging.info("Updating Windows components...")
    commands = [
        ["powershell", "-Command", "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"],
        ["powershell", "-Command", "Install-Module -Name PSWindowsUpdate -Force -AllowClobber"],
        ["powershell", "-Command", "Import-Module PSWindowsUpdate; Install-WindowsUpdate -AcceptAll -AutoReboot"]
    ]
    return [run_command(cmd) for cmd in commands]

def update_winget_packages():
    logging.info("Updating Winget packages...")
    return run_command(["winget", "upgrade", "--all", "--include-unknown"])

def update_chocolatey_packages():
    logging.info("Updating Chocolatey packages...")
    return run_command(["choco", "upgrade", "all", "-y"])

def is_chocolatey_installed():
    try:
        subprocess.run(["choco", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        logging.info("Chocolatey not found.")
        return False

def update_windows_store():
    logging.info("Updating Microsoft Store apps...")
    store_update_cmd = ["powershell", "-Command", "Get-AppxPackage | Foreach { Update-AppxPackage $_.PackageFullName }"]
    return run_command(store_update_cmd)

def run_updates_concurrently():
    with ThreadPoolExecutor() as executor:
        futures = [executor.submit(update_windows), executor.submit(update_winget_packages), executor.submit(update_windows_store)]
        if is_chocolatey_installed():
            futures.append(executor.submit(update_chocolatey_packages))
        
        for future in as_completed(futures):
            future.result()  # Ensure all tasks complete

def main():
    if not is_admin():
        logging.warning("Script requires admin privileges, attempting to elevate...")
        run_as_admin()
        sys.exit()

    setup_logging()
    logging.info("Software update initiated.")
    
    run_updates_concurrently()

    logging.info("Software update completed.")

if __name__ == "__main__":
    main()
