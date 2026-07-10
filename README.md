MacOS Utilities with ChatGPT
=============================

A collection of macOS automation and system-maintenance shell scripts and AppleScripts —
Homebrew cleanup, app uninstallation, startup/process auditing, media file housekeeping, and
Apple Music library tools — built and refined with the help of ChatGPT. The repo also
includes a handful of companion scripts for Linux server maintenance and Windows software
updates.

These are practical, single-purpose scripts you can run standalone from the terminal; no
build step, package manager, or dependencies beyond the tools each script itself calls out
(Homebrew, `ffprobe`, `AtomicParsley`, etc.).

Installation
------------

1. Clone this repository:
   ```bash
   git clone https://github.com/DavidVeksler/MacOS_Utilities_With_ChatGPT.git
   cd MacOS_Utilities_With_ChatGPT
   ```
2. Make the script(s) you want to use executable:
   ```bash
   chmod +x script_name.sh
   ```
3. Run it from the terminal: `./script_name.sh`. Some scripts require administrator
   privileges and will prompt for your password (`sudo`) when needed.

macOS utilities
----------------

| Script | Description |
|---|---|
| `macos_maintenance.sh` | General macOS maintenance: cleans temporary files, updates macOS software, and runs common housekeeping tasks, with timestamped logging to `maintenance_<timestamp>.log`. |
| `update-software.sh` | Updates all Homebrew formulae and casks in one pass, keeps `sudo` alive for the duration, and logs results to `~/update-software.log`. Intended to be run manually or as a scheduled task. |
| `fix-brew-issues.sh` | Fixes a set of known/recurring Homebrew cask problems (e.g. broken OnyX/wireshark-app/coconutBattery installs, orphaned Caskroom directories), then runs `brew cleanup` and `brew doctor`. |
| `find_unmanaged_apps.sh` | Scans `/Applications` for apps not installed via Homebrew and checks whether a matching Homebrew formula/cask exists, so you can migrate them under Homebrew management. |
| `uninstaller.sh` | Uninstalls a macOS app and its associated support files. Runs a dry-run first to preview everything that would be deleted, then asks for confirmation before removing anything. Usage: `./uninstaller.sh <AppName>`. |
| `process_inspector.sh` | Lists running non-Apple processes with PID, user, CPU%, memory%, and command, to help spot unwanted or resource-heavy background processes. |
| `startup_inspector.sh` | Lists non-Apple login items, launch agents, and launch daemons configured to start automatically on macOS. |
| `delete_empty_folders.sh` | Recursively deletes all empty folders under a given directory. Usage: `./delete_empty_folders.sh <directory>`. |
| `file_dates_should_match_id3_tags.sh` | Rewrites a music file's (and its parent folder's) file-system dates to match the date embedded in its ID3/metadata tags (mp3, aac, m4a). Requires `id3tool`, `AtomicParsley`, and `SetFile`. |
| `recursive_git_fetch_pull.sh` | Recursively finds every git repository under a given directory and runs `fetch`/`pull` on each one. Usage: `./recursive_git_fetch_pull.sh <directory>`. |

Apple Music automations (`Apple Music Automations/`)
------------------------------------------------------

AppleScripts that drive the macOS Music app directly:

| Script | Description |
|---|---|
| `delete_dead_tracks_applescript.scpt` | Removes library entries whose underlying audio file is missing/dead. |
| `remove_duplicate_tracks_applescript.scpt` | Finds and removes duplicate tracks from the Music library. |
| `apple_music_genre_report.scpt` | Generates a report of the Music library broken down by genre. |
| `Export Music Library To CSV.scpt` | Exports the Music library's track metadata to a CSV file. |

Run these by double-clicking to open in Script Editor, or via `osascript path/to/script.scpt`.

Media transcoding (`Transcoding/`)
------------------------------------

| Script | Description |
|---|---|
| `transcode_to_hevc.sh` | Converts video files in the current directory to HEVC (H.265) using `ffprobe`/`ffmpeg`, skipping files already encoded as HEVC. |
| `transcode_to_hevc_recursive.sh` | Same as above, but recurses into subdirectories. |
| `looping_script.sh` | Repeatedly re-runs `transcode_to_hevc_recursive.sh` in a loop, useful for watching a folder that receives new files over time. |

Also included: Linux and Windows companions
----------------------------------------------

The repo has grown to include a couple of non-macOS maintenance scripts that share the same
"automate routine system upkeep" goal:

- `Linux/maintenance.sh` — cleanup script for Ubuntu servers running a WordOps
  (Nginx/MariaDB/PHP/WordPress) stack: prunes old temp files, nginx/PHP-FPM cache, rotated
  logs, `www` backups, and trims the systemd journal on configurable age thresholds. Must be
  run as root.
- `Windows/update_software.py` — comprehensive Windows updater that drives Winget,
  Chocolatey, the Microsoft Store, and Windows Update, with optional system health checks and
  cleanup steps.
- `Windows/clean_temp.py` — empties common Windows 10/11 temp folders (user and system temp
  directories), with dry-run mode and an age cutoff to avoid deleting recently modified files.

Contributing
------------

Contributions are welcome — feel free to open a pull request or an issue to report bugs or
suggest improvements.

License
-------

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
