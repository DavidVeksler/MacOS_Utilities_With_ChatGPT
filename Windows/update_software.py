import subprocess
import winreg
import os
import sys
import ctypes
import logging
from datetime import datetime

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
    logging.basicConfig(filename=log_file, level=logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s')

def run_command(command):
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        logging.info(f"Command '{' '.join(command)}' executed successfully.")
        return result.stdout
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing command '{' '.join(command)}': {e}")
        logging.error(f"Error output: {e.stderr}")
        return None

def update_windows():
    logging.info("Updating Windows...")
    
    # Install NuGet provider if not already installed
    run_command(["powershell", "-Command", 
                 "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"])
    
    # Install PSWindowsUpdate module
    run_command(["powershell", "-Command", 
                 "Install-Module -Name PSWindowsUpdate -Force -AllowClobber"])
    
    # Run Windows Update
    run_command(["powershell", "-Command", 
                 "Import-Module PSWindowsUpdate; Install-WindowsUpdate -AcceptAll -AutoReboot"])

def update_winget_packages():
    logging.info("Updating packages using winget...")
    run_command(["winget", "upgrade", "--all", "--include-unknown"])

def update_chocolatey_packages():
    logging.info("Updating packages using Chocolatey...")
    run_command(["choco", "upgrade", "all", "-y"])

def is_chocolatey_installed():
    try:
        subprocess.run(["choco", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    if not is_admin():
        logging.info("Script is not running with admin privileges. Attempting to elevate...")
        run_as_admin()
        return

    setup_logging()
    logging.info("Starting software update process...")

    update_windows()
    update_winget_packages()

    if is_chocolatey_installed():
        update_chocolatey_packages()
    else:
        logging.info("Chocolatey is not installed. Skipping Chocolatey updates.")

    logging.info("Software update process completed.")

if __name__ == "__main__":
    main()