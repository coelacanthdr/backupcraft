# Minecraft Backup Script (macOS)

A robust Bash script for automatically backing up your Minecraft server on macOS. Supports multi-tier backups (hourly, daily, weekly, monthly), RCON integration for safe backups, error reporting, and optional offsite iCloud backups. The intent is for this to be automated with launchd (below) to run every hour as cron is not well supported on macOS. Yes, I know that the use case here is people who have an old mac and want to dedicate it to a family minecraft server and don't want to convert it to Unix/Linux.  That's OK and what I was doing for, well, um...reasons.  I thought this would help a lot of people who try to do this and wind up with griefed worlds and crying kids because they failed to whitelist and never remember to backup their files or have the old mac die on them, get flooded or catch on fire.

---

## Key Features

- **Multi-tier Backup System** (hourly, daily, weekly, monthly)  
- **iCloud Offsite Backup** for redundancy  
- **RCON Integration** to safely flush world data  
- **Error Handling** with logs and notifications  
- **Automatic Cleanup** of old backups  
- **Checksum Verification** for integrity  

---

## Improvements / Fixes Implemented

1. Persistent single RCON session for multiple commands.  
2. Safe multi-tier backup rotation.  
3. Detailed error logging for backup and RCON failures.  
4. Offsite iCloud integration.  
5. Pre-flight checks for directories and tools.  
6. Locking mechanism to prevent overlapping runs.  
7. SHA-256 checksums for all backups.  

---

## Important Warnings / Security Tips

**File System Warnings:**  
- Do **not** place your Minecraft server or backup folders inside `Desktop`, `Documents`, or `Downloads`. These are protected macOS directories and may cause permission errors or prevent automatic backups.  
- Use a dedicated folder such as `~/MinecraftServer` or `~/MinecraftBackups` with full read/write permissions.

**RCON Security Warnings:**  
- RCON exposes your server to remote commands; **unauthorized access can compromise your server**.  
- Recommended precautions:  
  - Enable the **whitelist** on your server.  
  - Restrict RCON to **localhost** only (`127.0.0.1`).  
  - Use a **strong, unique password** for RCON.  
  - Configure appropriate **firewalls** to block unwanted access.  
  - Run the Minecraft server as a **limited-permission user** to sandbox potential exploits.  

**General Security:**  
- Always ensure backups and logs are in a secure location, preferably outside system-protected folders.  
- Never commit your RCON password or server credentials to public repositories--treat it like an admin password.
- Consider using other ports as most scanners just look at the defaults.

---

## Prerequisites

- macOS with Bash  
- [rcon-cli](https://github.com/Tiiffi/rcon-cli) installed (default path: `/usr/local/bin/rcon-cli`)  
- Access to Minecraft server RCON port
- know how to find the terminal in macOS and what it is used for
- A functioning minecraft server and know how to edit server.properties to enable rcon and set rcon password, port and ip

---

## Quick Setup Guide

1. **Clone the repository**
~~~
git clone https://github.com/coelacanthdr/backupcraft.git
cd minecraft-backup
chmod +x mc_backup.sh
~~~

2. **Edit the script to set your server paths, RCON credentials, and iCloud settings**  

### Quick Setup Cheat Sheet

| Section | Variable | Description | Example / Notes |
|---------|----------|-------------|----------------|
| **Paths** | `MCDIR` | Minecraft server folder | `/Users/username/MinecraftServer` |
|  | `WORLD` | Minecraft world folder | `$MCDIR/world` |
|  | `BACKUPROOT` | Main backup folder | `/Users/username/MinecraftBackups` |
|  | `LOGFILE` | Path for backup logs | `$BACKUPROOT/backup.log` |
|  | `LOCKDIR` | Temporary lock directory | `/tmp/minecraft_backup.lockdir` (leave as is) |
| **RCON** | `RCON_HOST` | IP address of Minecraft server | `127.0.0.1` |
|  | `RCON_PORT` | RCON port | `25575` |
|  | `RCON_PASS` | RCON password | `your_rcon_password` |
| **iCloud Backup (Optional)** | `ICLOUD_ROOT` | Root iCloud folder | `~/Library/Mobile Documents/com~apple~CloudDocs/MinecraftBackup` |
|  | `ICLOUD_WEEKLY` | Weekly iCloud backup folder | `$ICLOUD_ROOT/weekly` |
|  | `ICLOUD_RETAIN_WEEKLY` | Number of weekly iCloud backups to keep | `8` |
| **Retention Settings** | `RETAIN_HOURLY` | Number of hourly backups to keep | `24` |
|  | `RETAIN_DAILY` | Number of daily backups to keep | `7` |
|  | `RETAIN_WEEKLY` | Number of weekly backups to keep | `5` |
|  | `RETAIN_MONTHLY` | Number of monthly backups to keep | `12` |

**Tips:**  
- Use absolute paths to avoid launchd errors.  
- Ensure directories exist before running the script or launchd job.  
- Keep RCON credentials secure—never commit them publicly.  

3. **Run manually to test**
~~~
./mc_backup.sh
~~~

---

## Automating Backups with launchd

Since `cron` is deprecated on macOS, the recommended way to schedule recurring backups is **launchd**.  

### 1. Create a launch agent plist file

Create a file in `~/Library/LaunchAgents/`, for example:

~/Library/LaunchAgents/com.user.minecraft.backup.plist


Add the following content:

~~~
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <key>Label</key>
    <string>com.user.minecraft.backup</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/user/bin/mc_backup.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>/Users/user/Minecraft/backups/launchd.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/user/Minecraft/backups/launchd.log</string>

    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
~~~

**Notes:**  
- Replace `/Users/user/bin/mc_backup.sh` with the full path to your script.
- Replace `/Users/user/Minecraft/backups/launchd.log` with the full path to your log.
- Replace `com.user.minecraft.backup` with the name of your plist file without the ".plist" at the end.
- Logs will be written to `launchd.log`; ensure the directory exists.  

### 2. Load the launch agent
~~~
launchctl load ~/Library/LaunchAgents/com.user.minecraft.backup.plist
~~~

### 3. Unload the launch agent
~~~
launchctl unload ~/Library/LaunchAgents/com.user.minecraft.backup.plist
~~~

### 4. Verify it’s loaded
~~~
launchctl list | grep minecraft
~~~

This setup will run your backup script at the top of every hour. You can adjust `StartCalendarInterval` in the plist for other schedules.

---

## Logging

- Backup logs: `$BACKUPROOT/backup.log`  
- RCON errors automatically logged  
- `pax` warnings captured in `$BACKUPROOT/pax_error.log`  
- launchd logs: as specified in the plist (`launchd.log`)  

---

## Contributing

Pull requests welcome! Ensure sensitive credentials are removed before submitting.

---

## License

MIT License – free to use, modify, and distribute.
