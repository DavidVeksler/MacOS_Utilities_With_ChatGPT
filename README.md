MacOS Utilities with ChatGPT
============================

This repository contains a collection of utilities for MacOS, designed to simplify and automate various tasks. These utilities have been created with the help of ChatGPT, an advanced AI language model.

Utilities
---------

-   find_unmanaged_apps.sh: Finds all apps that are not managed by Homebrew and offers to replace them with the Homebrew version.
-   transcode_to_hevc.sh and transcode_to_hevc_recursive.sh: Converts all non-HEVC videos in a directory to HEVC format. The _recursive version processes directories recursively.
-   update-software.sh: Updates Homebrew apps as a scheduled task.
-   looping_script.sh: A helper script to run bash scripts in a loop.
-   macos_maintenance.sh: Performs MacOS maintenance tasks like cleaning temporary files, updating MacOS software, and more.

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
