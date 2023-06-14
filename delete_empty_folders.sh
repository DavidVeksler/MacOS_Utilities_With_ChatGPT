#!/usr/bin/env bash

# Check if a directory is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Find and remove all empty directories
find "$1" -type d -empty -delete
