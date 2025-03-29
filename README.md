### BasicEnum
Bash Scripts for basic Enumeration of systems.

This particular script currently runs through a basic enumeration of a linux system and prepares the output for quick exfiltration if you so desire. 

This enumeration script will run through and quickly produce useful imformation about a target machine, then give you the option to quickly exfiltrate it back to your (the attacking) machine. 

#### Key Features and flow
1. Prompts if you want to ultimately save the outputs as a file
2. Gathers basic system and user info 
3. Runs sudo -l and checks gtfo bins for available exploit
4. Searches GTFO Bins (Either locally against "gtfobins.txt" or will curl the website
	Note: I have included a list of binaries found on GTFO bins for local checks (in case the tgt machine cannot curl)
5. Will do a few basic searches for keywords (currently only "Password")
6. Show any backup files, Binaries with SUID permissions
7. Give options on how or if you want to exfilatrate the output file 
	Note: Currently the only exfiltration options are a SCP Push back to your local (attacker machine) or setting up a python server for you to do a wget request from. 
	
If you want to update the GTFO List before infiltration run this command 


`curl -s https://gtfobins.github.io/ | grep -oP '(?<=/gtfobins/)[^/"]+' | sort -u > gtfobins.txt` 
