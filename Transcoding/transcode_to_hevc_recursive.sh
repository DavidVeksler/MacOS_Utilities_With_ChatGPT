#!/bin/bash

# Function to check video codec
function check_codec() {
  local input_file="$1"
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file"
}

# Set the quality parameter (lower values = higher quality, larger file size)
quality=22

# Supported input formats
input_formats=("mp4" "mkv" "avi" "mov" "flv" "wmv")

# Check if a directory is specified as an argument
if [ -z "$1" ]; then
  echo "Please provide a directory as an argument."
  exit 1
fi

# Start transcoding process
for format in "${input_formats[@]}"; do
  find "$1" -type f -iname "*.$format" | while read -r input_file; do
    codec=$(check_codec "$input_file")

    if [ "$codec" != "hevc" ]; then
      temp_output="${input_file%.*}_temp.$format"
      echo "Transcoding $input_file to HEVC..."
      if HandBrakeCLI -i "$input_file" -o "$temp_output" -e x265 -q "$quality" --all-audio --all-subtitles; then
        mv "$temp_output" "$input_file"
        echo "Transcoding complete for $input_file"
      else
        echo "Error transcoding $input_file. Skipping."
        rm -f "$temp_output"
      fi
    else
      echo "Skipping $input_file (already in HEVC format)"
    fi
  done
done
