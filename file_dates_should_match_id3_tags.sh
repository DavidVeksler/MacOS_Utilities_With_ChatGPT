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
    elif [[ $file == *.aac ]]; then
        year=$(AtomicParsley "$file" -t | grep '©day' | awk '{print $3}' | cut -c 1-4)
    else
        echo "Unsupported file type: $file"
        return
    fi

    # Check if year is a valid 4-digit year
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        # Format the date string for SetFile command
        date_str="01/01/${year} 00:00:00"

        # Change the creation and modification date of the file
        SetFile -d $date_str -m $date_str "$file"

        # Change the creation and modification date of the parent directory
        dirname=$(dirname "$file")
        SetFile -d $date_str -m $date_str "$dirname"
    else
        echo "Invalid year '$year' in file $file"
    fi
}

# Find all mp3 and aac files recursively from the specified directory
find "$1" -type f \( -iname "*.mp3" -o -iname "*.aac" \) | while read -r file; do
    process_file "$file"
done
