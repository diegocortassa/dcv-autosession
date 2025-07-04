#!/usr/bin/bash
# dcv_reset_display.sh
# Reset monitor transform chnaged when using a console session

# NOTE: this works only for console sessions
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:1
    echo "Display set to $DISPLAY"
fi

for MONITOR in $(xrandr | grep " connected" | awk '{ print $1}'); do
    echo "Resetting $MONITOR transform for display $DISPLAY"
    xrandr --output $MONITOR --transform none
done
# Wait for screens to settle
sleep 2
echo "Reloading gnome-shell to reset monitor conf"
killall -HUP gnome-shell
