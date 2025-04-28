#!/bin/bash
# ask user password to unlock the keyring

ask_pass() {
    # pinentry gives a nice modal dialog, but just in case we fallback to zenity
    if command -v pinentry >/dev/null; then
        prompt=$1
        # echo -e "SETPROMPT $prompt\nGETPIN\nBYE" | pinentry-gnome3 | grep -E '^D ' | sed 's/D //'
        {
            echo "SETTITLE Info"
            echo "SETPROMPT $prompt"
            echo "SETDESC The password is needed to unlock you keyring"
            echo "GETPIN"
            echo "BYE"
        } | pinentry | grep -E '^D ' | sed 's/D //'
    else
        echo "$(zenity --password)"
    fi
}


ask_new_pass() {
    local password1
    local password2
    password1=$(ask_pass 'Enter your password:')
    password2=$(ask_pass 'Confirm password:')

    if [ "$password1" == "$password2" ]; then
        echo "$password1"  # echo the password to return it
        return 0  # passwords match
        
    else
        echo "Passwords do not match. Please try again."
        return 1  # passwords do not match
    fi
}


show_message() {
    local message="$1"
    if command -v pinentry >/dev/null; then
        # Start a pinentry session
        {
            echo "SETTITLE Info"
            echo "SETPROMPT "
            echo "SETDESC $message"
            echo "CONFIRM"
            echo "BYE"
        } | pinentry
    else
            zenity --info --title="Info" --text="$message"
    fi
}


if [ ! -f "$HOME/.local/share/keyrings/login.keyring" ]; then
    echo "No keyfile"
    while true; do
        password=$(ask_new_pass)
        if [ $? -eq 0 ]; then
            echo -n "$password" | gnome-keyring-daemon --replace --unlock
            break
        fi
    show_message 'Passwords do not match, enter password again'
    done
fi

for _ in $(seq 1 5); do
    LOCKED=$(busctl -j --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked | jq .data)
    if [[ "$LOCKED" == "true" ]]; then
        PASSWORD=$(ask_pass 'Enter your password:')
        export $(echo -n "$PASSWORD" | gnome-keyring-daemon --replace --unlock)
        echo "$PASSWORD"
    else
        exit 0
    fi
done
