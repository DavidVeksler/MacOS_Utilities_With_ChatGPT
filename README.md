MacOS Utilities with ChatGPT
============================

This repository contains a collection of utilities for MacOS, designed to simplify and automate various tasks. These utilities have been created with the help of ChatGPT, an advanced AI language model.

Utilities
---------

-   **find_unmanaged_apps.sh**: Finds all apps that are not managed by Homebrew and offers to replace them with the Homebrew version.
-  ** transcode_to_hevc.sh** and transcode_to_hevc_recursive.sh: Converts all non-HEVC videos in a directory to HEVC format. The _recursive version processes directories recursively.
-   **update-software.sh**: Updates Homebrew apps as a scheduled task.
-   **looping_script.sh**: A helper script to run bash scripts in a loop.
-   **macos_maintenance.sh**: Performs MacOS maintenance tasks like cleaning temporary files, updating MacOS software, and more.
-   **delete_dead_tracks_applescript**: Deletes deleted files from Apple Music.
-   **remove_duplicate_tracks_applescript**: Removes duplicate tracks in Apple Music.
-   **delete_empty_folders.sh**: Deletes any empty folders in a specified directory.
-   **file_dates_should_match_id3_tags.sh**: Updates the file and folder dates to match the metadata in mp3, aac, and m4a files.


Uninstaller.sh:
------------

### Uninstaller Script for macOS

#### Description

This Uninstaller Script is a powerful and user-friendly tool designed for macOS systems. It allows users to safely and effectively remove applications along with their associated files from their system. Initially, the script performs a "dry run" to display all the files and directories it intends to delete, providing users with a clear understanding of the actions that will be taken. After reviewing this information, users can then choose to proceed with the actual uninstallation process.

#### Features

- **Dry Run Preview**: Initially runs in a dry run mode to list all files and directories that would be deleted, without making any changes.
- **User Confirmation**: Prompts users for confirmation before proceeding with the actual file deletion, enhancing safety and control.
- **Running Process Check**: Checks and warns if there are any running processes related to the application, suggesting their termination before proceeding.
- **Verbose Output**: Provides detailed information about each operation, including file sizes and statuses.
- **Safety Checks**: Includes checks for system applications and restricted files to prevent accidental system damage.

#### Usage

1. **Running the Script**:
   To run the script, use the following command in the terminal:

   ```bash
   ./uninstaller.sh <AppName>
   ```

   Replace `<AppName>` with the name of the application you want to uninstall. For example, to uninstall an app named "SampleApp", you would run:

   ```bash
   ./uninstaller.sh SampleApp
   ```

2. **Reviewing Dry Run Output**:
   The script first executes in dry run mode, listing all files and directories it plans to delete. Review this list carefully to understand what will be affected.

3. **Confirming Uninstallation**:
   After the dry run, the script will ask for your confirmation to proceed with the actual uninstallation. Type `y` to proceed or `n` to abort.

#### Requirements

- macOS operating system.
- Bash shell (script is not compatible with `sh` or other shells).
- Sufficient permissions (running the script with `sudo` is recommended for thorough cleanup).

#### Important Notes

- Always back up important data before running scripts that modify or delete files

Installation
------------

1.  Clone this repository to your local machine.
2.  Ensure that the scripts are executable by running `chmod +x script_name.sh` for each script.

Usage
-----

To use any of the scripts, navigate to the directory containing the script and run it using `./script_name.sh`. Some of the scripts may require administrator privileges, which they will ask for.

For example, to run the MacOS maintenance script:

`cd path/to/MacOS_Utilities_With_ChatGPT
./macos_maintenance.sh`

Contributing
------------

Contributions to this project are welcome! Please feel free to submit a pull request or open an issue to report bugs or suggest improvements.

License
-------

This project is licensed under the Apache License 2.0. See the [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
