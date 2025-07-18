# Ombi Auto-Updater

Simple Bash script to update an Ombi systemd install to the latest GitHub release.

## Features

- Checks latest version via GitHub API  
- Backs up current install  
- Downloads and installs latest release  
- Restores database files  
- Restarts Ombi  
- Optional Slack/Discord notifications

## Usage
Make it executable:  
chmod +x ombi.sh  
Then run:  
sudo ./ombi.sh  

## How to check your Ombi setup

Run this to view your systemd service:

systemctl cat ombi

Look for:

- `User=` → use as `OMBI_USER`
- `WorkingDirectory=` → use as `WORKING_DIR`
- Optional: `--storage` argument in `ExecStart=` → that's your database folder

## Based on

https://github.com/lordvon01/updateOMBI  
https://github.com/carnivorouz/updateOmbi

Output and prompts are in Dutch.
