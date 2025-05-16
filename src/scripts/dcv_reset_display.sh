#!/bin/bash
# dcv_reset_display.sh
# Reset monitor transform chnaged when using a console session

for MONITOR in $(xrandr | grep " connected" | awk '{ print $1}'); do
    echo "Resetting $MONITOR transform"
    xrandr --output $MONITOR --transform none
done