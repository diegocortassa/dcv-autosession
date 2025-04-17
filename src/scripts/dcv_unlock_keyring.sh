#!/bin/bash                                                                             
# ask user password to unlock the keyring                                               
                                                                                        
askpass() {                                                                             
    # pinentry gives a nice modal dialog, but just in case we fallback to zenity               
    if command -v pinentry >/dev/null; then                                             
        prompt=$1                                                                       
        echo -e "SETPROMPT $prompt\nGETPIN\nBYE" | pinentry-gnome3 | grep -E '^D ' | sed 's/D //'
    else                                                                                
        echo $(zenity --password)                                                       
    fi                                                                                  
}                                                                                       
                                                                                        
for I in $(seq 1 3); do                                                                 
    LOCKED=$(busctl -j --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked | jq .data)
    if [[ "$LOCKED" == "true" ]]; then                                                  
      PASSWORD=$(askpass 'Enter your password:')                                        
      export $(echo -n "$PASSWORD" | gnome-keyring-daemon --replace --unlock)           
      echo $PASSWORD
    else                                                                                
        exit 0                                                                          
    fi                                                                                  
done                                                                                    
