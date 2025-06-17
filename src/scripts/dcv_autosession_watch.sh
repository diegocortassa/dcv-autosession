#!/usr/bin/bash
# dcv_autosession_watch.sh
# check if there is an unused DCV autosession and close it

# Configuration defaults
WATCH_INTERVAL=60  # Check every 60 seconds
DCV_CMD="/usr/bin/dcv"
DEBUG=false

# Load configuration, overrides defaults
[ -f "/etc/dcv/dcv_autosession.env" ] && source "/etc/dcv/dcv_autosession.env" 

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# Helper functions
get_current_autosession_connections() {
    "$DCV_CMD" list-sessions -j | jq -r '[.[] | select(.id == "autosession" and .type == "console")][0]."num-of-connections" // "null"'
}

get_current_autosession_user() {
    "$DCV_CMD" list-sessions -j | jq -r '[.[] | select(.id == "autosession" and .type == "console")][0].owner // "null"'
}

# check if there is an open gnome session
is_gnome_session_active() {
    local user="$1"
    return $(pgrep -u "$user" -x gnome-session >/dev/null || pgrep -u "$user" -x gnome-shell >/dev/null)
}


# Main execution
main() {
    connected_sessions=$(get_current_autosession_connections)

    ## guard clauses
    # No autosession found
    if [ "$connected_sessions" == "null" ]; then
        $DEBUG && log "No autosession found."
        return
    fi

    # Autosession is connected
    if [ "$connected_sessions" -gt "0" ]; then
        $DEBUG && log "autosession is connected."
        return
    fi

    curr_user=$(get_current_autosession_user)

    # User has a gnome session open
    if is_gnome_session_active "$curr_user"; then
        $DEBUG && log "Gnome session is active for user: $curr_user, resetting displays"
        su $curr_user bash -c /usr/bin/dcv_reset_display.sh
    fi

    # close the unused autosession
    log "Closing unused autosession for user: $curr_user..."
    "$DCV_CMD" close-session autosession

}

# Start the main loop
log "Autosession watch started. Monitoring for unused autosessions..."
while true; do
    main "$@"
    sleep $WATCH_INTERVAL  # Check every 60 seconds
done