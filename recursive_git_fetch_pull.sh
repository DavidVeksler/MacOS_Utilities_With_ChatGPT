# Don't forgot to run this script with bash, not shh
#!/bin/bash

# Check if a parameter has been passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Check if the directory exists
if [ ! -d "$1" ]; then
    echo "Error: Directory $1 does not exist."
    exit 1
fi

# Check if the directory is readable
if [ ! -r "$1" ]; then
    echo "Error: Directory $1 is not readable."
    exit 1
fi

# Specify the base directory you want to start from
BASE_DIR="$1"

# Find all .git directories under the base directory
while IFS= read -r -d '' git_dir
do
    # Get the parent directory of the .git directory, which is the git repo
    repo_dir=$(dirname "$git_dir")

    echo "Fetching and pulling in $repo_dir"

    # Change to the git repo directory and execute git fetch and git pull in the background
    (
        cd "$repo_dir" || exit
        git fetch --all
        if git pull; then
            echo "Successfully fetched and pulled $repo_dir"
        else
            echo "Failed to fetch and pull $repo_dir"
        fi
    ) &

    # Limit the number of background jobs to prevent system resource exhaustion
    if (( $(jobs -p | wc -l) >= 10 )); then
        wait -n
    fi
done < <(find "$BASE_DIR" -type d -name .git -print0)

# Wait for all background jobs to finish
wait
