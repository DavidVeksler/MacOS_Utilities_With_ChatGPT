#!/usr/bin/env bash

# Check if id3tool is installed
if ! command -v id3tool &> /dev/null; then
    echo "id3tool is not installed. Please install it and try again."
    exit 1
fi

# Check if AtomicParsley is installed
if ! command -v AtomicParsley &> /dev/null; then
    echo "AtomicParsley is not installed. Please install it and try again."
    exit 1
fi

# Check if SetFile is installed
if ! command -v SetFile &> /dev/null; then
    echo "SetFile is not installed. Please install Xcode Command Line Tools and try again."
    exit 1
fi

# Check if a directory is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Function to process a file
process_file() {
    local file=$1
    local year

    # Determine file type and extract the year accordingly
    if [[ $file == *.mp3 ]]; then
        year=$(id3tool "$file" | grep 'Year:' | awk '{print $2}')
    elif [[ $file == *.aac ]] || [[ $file == *.m4a ]]; then
        year=$(AtomicParsley "$file" -t | grep '©day' | awk '{print $3}' | cut -c 1-4)
    else
        echo "Unsupported file type: $file"
        return
    fi

    # Check if year is a valid 4-digit year
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        # If the year is before 1970, set it to 1970
        if [[ $year -lt 1970 ]]; then
            year=1970
        fi

        # Format the date string for SetFile command
        date_str="01/01/${year} 00:00:00"

        # Get the current creation date of the file
        current_date=$(GetFileInfo -d "$file")

        # Only update the date if it's not already correct
        if [[ "$current_date" != *"$year"* ]]; then
            # Change the creation and modification date of the file
            SetFile -d "$date_str" -m "$date_str" "$file"
        fi

        # Change the creation and modification date of the parent directory (+1 level up)
        dirname=$(dirname "$file")
        parent_dir=$(dirname "$dirname")
        current_dir_date=$(GetFileInfo -d "$dirname")

        # Only update the date if it's not already correct
        if [[ "$current_dir_date" != *"$year"* ]]; then
            SetFile -d "$date_str" -m "$date_str" "$dirname"
            SetFile -d "$date_str" -m "$date_str" "$parent_dir"
        fi
    else
        echo "Invalid year '$year' in file $file"
    fi
}

# Find all mp3 and aac files recursively from the specified directory
find "$1" -type f \( -iname "*.mp3" -o -iname "*.aac" \) | while read -r file; do
    process_file "$file"
done
