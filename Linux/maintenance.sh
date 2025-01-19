#!/usr/bin/env bash
###############################################################################
# Enhanced Cleanup Script for Ubuntu with WordOps (Nginx/MariaDB/PHP/WordPress)
###############################################################################

# CONFIGURATION
# Adjust these as needed
DAYS_FOR_TMP=2
DAYS_FOR_VAR_TMP=7
DAYS_FOR_NGINX_CACHE=2
DAYS_FOR_PHP_FPM_CACHE=2
DAYS_FOR_NGINX_LOGS=30
DAYS_FOR_WWW_BAK=7
DAYS_FOR_SYSTEMD_JOURNAL="30d"

###############################################################################
# PRE-CHECK
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run as root (sudo)."
  exit 1
fi

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

check_space() {
  echo -e "Disk usage (root /):"
  df -h / | grep -v "Filesystem"
}

cleanup_files_older_than() {
  local target_dir="$1"
  local keep_days="$2"
  local name_filter="$3"    # e.g., *.tmp
  local file_type="${4:-f}" # default type: files

  if [ -d "$target_dir" ]; then
    echo "Cleaning $target_dir: removing '$name_filter' older than $keep_days days."
    find "$target_dir" -type "$file_type" -name "$name_filter" -mtime +"$keep_days" -exec rm -f {} \; 2>/dev/null
  fi
}

cleanup_dir_all_files_older_than() {
  local target_dir="$1"
  local keep_days="$2"

  if [ -d "$target_dir" ]; then
    echo "Cleaning $target_dir: removing ALL files older than $keep_days days."
    find "$target_dir" -type f -mtime +"$keep_days" -delete 2>/dev/null
    # Remove empty directories too
    find "$target_dir" -type d -empty -delete 2>/dev/null
  fi
}

# Might want to compress logs older than X days instead of outright deleting them. 
# Replace -delete with something like:
# find "$dir" -name "*.log" -mtime +$days -exec gzip {} \;
compress_or_delete_logs() {
  local dir="$1"
  local days="$2"
  if [ -d "$dir" ]; then
    echo "Handling logs in $dir older than $days days..."
    # Example: compress them
    # find "$dir" -type f -name "*.log" -mtime +"$days" -exec gzip {} \; 2>/dev/null
    # Or delete them:
    find "$dir" -type f -name "*.log" -mtime +"$days" -delete 2>/dev/null
  fi
}

###############################################################################
# MAIN SCRIPT
###############################################################################

echo "============================="
echo "System cleanup started..."
echo "============================="

echo -e "\n--- Space before cleanup ---"
check_space
echo

# WordPress/WordOps-specific cleanup
if [ -d "/var/www" ]; then
  echo "=== Cleaning WordPress/WordOps directories (/var/www) ==="
  # Remove .tmp, .temp (any day old) and .bak older than $DAYS_FOR_WWW_BAK
  cleanup_files_older_than "/var/www" 0 "*.tmp"
  cleanup_files_older_than "/var/www" 0 "*.temp"
  cleanup_files_older_than "/var/www" "$DAYS_FOR_WWW_BAK" "*.bak"
  # If you have WordOps backups in /var/www/backup or something, handle them here.
  # e.g., cleanup_files_older_than "/var/www/backup" 30 "*.tar.gz"
fi

# Generic temp dirs
cleanup_dir_all_files_older_than "/tmp" "$DAYS_FOR_TMP"
cleanup_dir_all_files_older_than "/var/tmp" "$DAYS_FOR_VAR_TMP"
cleanup_dir_all_files_older_than "/var/cache/nginx" "$DAYS_FOR_NGINX_CACHE"
cleanup_dir_all_files_older_than "/var/cache/php-fpm" "$DAYS_FOR_PHP_FPM_CACHE"

# Logs
compress_or_delete_logs "/var/log/nginx" "$DAYS_FOR_NGINX_LOGS"
# If WordOps puts logs elsewhere, do it similarly.

# Clean package manager caches
echo "=== Cleaning apt/dpkg caches ==="
apt-get clean
apt-get autoclean -y
apt-get autoremove -y

# Vacuum systemd journals
echo "=== Cleaning old systemd journals (older than $DAYS_FOR_SYSTEMD_JOURNAL) ==="
journalctl --vacuum-time="$DAYS_FOR_SYSTEMD_JOURNAL"

# MariaDB cleanup
if [ -d "/var/lib/mysql/mysql" ]; then
  echo "=== Cleaning MariaDB temp files ==="
  # Removing common MySQL/MariaDB leftover artifacts
  find /var/lib/mysql -name "*.TMD" -type f -delete 2>/dev/null
  find /var/lib/mysql -name "*.ARM" -type f -delete 2>/dev/null
  find /var/lib/mysql -name "*.TRG" -type f -delete 2>/dev/null
fi

# Service restarts (Nginx, PHP-FPM, MariaDB)
# If you have multiple PHP-FPM versions, might want to loop them
echo -e "\n=== Restarting services ==="
systemctl restart nginx php*-fpm mariadb

echo -e "\n--- Space after cleanup ---"
check_space

echo -e "\nCleanup complete!\n"
exit 0
