#!/bin/bash 
# dcv_pam_exec_autosession
# Create a session for the user logging in and enable collaboration
#
# Run by pam_exec auth configured in /etc/dcv/dcv.conf pam-service-name and /etc/pam.d/dcv-autosession
# Runs as root user

# Configuration
DEBUG=false  # Options: false|true
SESSION_TYPE="virtual" # Options: virtual|console
LOG_FILE="/var/log/dcv/dcv_autosession.log"

SESSION_NAME="autosession"
DCV_CMD="/usr/bin/dcv"
DCV_COLLAB_PROMPT="/usr/bin/dcv_collab_prompt.sh"
DCV_PERM_FILE="/etc/dcv/default.perm"
COLLAB_PERM_FILE="/tmp/dcv_collab.perm"

[ -f "/etc/dcv/dcv_autosession.env" ] && source "/etc/dcv/dcv_autosession.env" 

read -r PASSWORD

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# Helper functions
get_current_session_user() {
    "$DCV_CMD" list-sessions -j | jq -r '.[0].owner // "null"'
}

get_current_session_type() {
    "$DCV_CMD" list-sessions -j | jq -r '.[0].type // "null"'
}

get_session_id() {
    "$DCV_CMD" list-sessions -j | jq -r '.[0].id // "null"'
}

is_user_logged_in() {
    local user="$1"
    pgrep -u "$user" -x gnome-session >/dev/null || pgrep -u "$user" -x gnome-shell >/dev/null
}

# Session management functions
handle_existing_session() {
    local curr_user="$1"
    local pam_user="$2"

    if [ "$curr_user" == "$pam_user" ]; then
        log "Reusing existing session for $pam_user"
        "$DCV_CMD" list-sessions
        exit 0
    fi
}

cleanup_unused_console_session() {
    local curr_user="$1"
    local curr_type="$2"
    local pam_user="$3"

    if ! is_user_logged_in "$curr_user" && \
       [ "$curr_type" == "console" ]; then
        log "Closing unused console session"
        "$DCV_CMD" close-session "$SESSION_NAME"
        return 0
    fi
    return 1
}

setup_collaboration() {
    local curr_user="$1"
    local pam_user="$2"
    local session_id
    
    log "Requesting collaboration for user $pam_user with $curr_user"
    local accepted
    accepted=$("$DCV_COLLAB_PROMPT" "$curr_user" "$pam_user" 10)
    session_id=$(get_session_id)

    case "$accepted" in
        "Full control")
            log "Collaboration request accepted with full control"
            sed -n '/\[permissions\]/,$p' "$DCV_PERM_FILE" > "$COLLAB_PERM_FILE"
            echo "$pam_user allow builtin" >> "$COLLAB_PERM_FILE"
            ;;
        "View only")
            log "Collaboration request accepted with view-only access"
            sed -n '/\[permissions\]/,$p' "$DCV_PERM_FILE" > "$COLLAB_PERM_FILE"
            echo "$pam_user allow display pointer" >> "$COLLAB_PERM_FILE"
            ;;
        *)
            log "Collaboration request rejected"
            exit 2
            ;;
    esac

    "$DCV_CMD" set-permissions --session "$session_id" --file "$COLLAB_PERM_FILE"
    exit 0
}

create_new_session() {
    local pam_user="$1"

    if [ "$SESSION_TYPE" == "virtual" ]; then
        # unlock user's login gnome-keyring for virtual sessions
        echo "$PASSWORD" | sudo -H -u "$pam_user" /usr/bin/gnome-keyring-daemon --daemonize --login
    fi

    log "Creating new $SESSION_TYPE session for user $pam_user"
    "$DCV_CMD" create-session --type "$SESSION_TYPE" --owner "$pam_user" "$SESSION_NAME"
    "$DCV_CMD" list-sessions
}

# Main execution
main() {
    [[ "$DEBUG" == "true" ]] && set -x
    exec > $LOG_FILE 2>&1

    log "Starting DCV autosession management"
    log "Environment variables:"
    env

    local curr_user
    curr_user=$(get_current_session_user)

    # If a session for the current user exists we just exit 0 and let it reconnect to the session
    # Handle existing session
    handle_existing_session "$curr_user" "$PAM_USER"

    # Check for unused console session
    # If there is a console session but no user logged in we close it
    # TODO find a way do close console sessions when the user logouts
    local curr_session_type
    curr_session_type=$(get_current_session_type)
    cleanup_unused_console_session "$curr_user" "$curr_session_type" "$PAM_USER" && curr_user="null"

    # Handle collaboration or create new session
    if [ "$curr_user" != "null" ]; then
        setup_collaboration "$curr_user" "$PAM_USER"
    else
        create_new_session "$PAM_USER"
    fi

    log "Session management completed"
}

main "$@"