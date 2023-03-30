#!/bin/bash
while true
do
    sh transcode_to_hevc_recursive.sh .
    sleep 1    # optional: add a sleep command to add a delay between each iteration of the loop
done
