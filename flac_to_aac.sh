#!/bin/bash

# Check if a directory has been provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 directory_path"
    exit 1
fi

# Check if the provided directory exists
if [ ! -d "$1" ]; then
    echo "Directory $1 does not exist."
    exit 1
fi

# Create a log file
log_file="conversion.log"
echo "Conversion log - $(date)" > "$log_file"

# Change to the provided directory
cd "$1"

# Convert all .flac files to .aac
for file in *.flac; do
    if [ -f "$file" ]; then
        echo "Converting $file..." >> "$log_file"
        if ffmpeg -i "${file}" -vn -acodec aac -map_metadata 0 "${file%.flac}.m4a" >> "$log_file" 2>&1; then
            echo "$file converted successfully." >> "$log_file"
        else
            echo "Error converting $file." >> "$log_file"
        fi
    fi
done

echo "Conversion completed. See $log_file for details."
