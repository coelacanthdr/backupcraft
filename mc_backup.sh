#!/bin/bash
####################################
# Minecraft Backup Script (macOS)
# With Error Reporting and Multi-tier Backups
####################################

set -o pipefail

############################
# Paths
############################
MCDIR="/Users/username/MinecraftServer"
WORLD="$MCDIR/world"
BACKUPROOT="/Users/username/MinecraftBackups"
LOGFILE="$BACKUPROOT/backup.log"
LOCKDIR="/tmp/minecraft_backup.lockdir"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Another backup is already running, exiting" >> "$LOGFILE"
    exit 0
fi

trap 'rmdir "$LOCKDIR"' EXIT

############################
# RCON
############################
RCON_HOST="127.0.0.1"
RCON_PORT="25575"
RCON_PASS="your_rcon_password"

############################
# Timestamp
############################
NOW=$(date +"%Y-%m-%d_%H-%M-%S")

############################
# Backup folders
############################
HOURLY="$BACKUPROOT/hourly"
DAILY="$BACKUPROOT/daily"
WEEKLY="$BACKUPROOT/weekly"
MONTHLY="$BACKUPROOT/monthly"

mkdir -p "$HOURLY" "$DAILY" "$WEEKLY" "$MONTHLY"

############################
# Retention counts
############################
RETAIN_HOURLY=24
RETAIN_DAILY=7
RETAIN_WEEKLY=5
RETAIN_MONTHLY=12

############################
# iCloud offsite backup (WEEKLY)
############################
ICLOUD_ROOT="/Users/username/Library/Mobile Documents/com~apple~CloudDocs/MinecraftBackup"
ICLOUD_WEEKLY="$ICLOUD_ROOT/weekly"
ICLOUD_RETAIN_WEEKLY=8

mkdir -p "$ICLOUD_WEEKLY"

############################
# Helper functions
############################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

# Persistent / batched RCON session
mc_batch() {
    local OUTPUT
    OUTPUT=$(/usr/local/bin/rcon-cli \
        --host "$RCON_HOST" \
        --port "$RCON_PORT" \
        --password "$RCON_PASS" <<EOF
$@
EOF
    )
    local STATUS=$?

    if [ $STATUS -ne 0 ]; then
        log "RCON ERROR: $OUTPUT"
        return 1
    fi
    return 0
}

fatal() {
    log "ERROR: $1"
    mc_batch "
say §c[Backup] ERROR: Backup failed — check server logs
"
    exit 1
}

purge_old_backups() {
    local DIR=$1
    local RETAIN=$2
    local COUNT

    COUNT=$(ls -1t "$DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$COUNT" -gt "$RETAIN" ]; then
        ls -1t "$DIR"/*.tar.gz | tail -n $((COUNT - RETAIN)) | while read -r FILE; do
            rm -f "$FILE"
            log "Purged old backup: $FILE"
        done
    fi
}

purge_old_icloud_backups() {
    local DIR=$1
    local RETAIN=$2
    local COUNT

    COUNT=$(ls -1t "$DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$COUNT" -gt "$RETAIN" ]; then
        ls -1t "$DIR"/*.tar.gz | tail -n $((COUNT - RETAIN)) | while read -r FILE; do
            rm -f "$FILE" "$FILE.sha256"
            log "Purged old iCloud backup: $FILE"
        done
    fi
}

checksum_file() {
    local FILE="$1"
    shasum -a 256 "$FILE" | awk '{print $1}' > "$FILE.sha256"
}

############################
# Pre-flight checks
############################

if [ ! -d "$WORLD" ]; then
    fatal "World directory not found at $WORLD"
fi

if ! command -v /usr/local/bin/rcon-cli >/dev/null 2>&1; then
    fatal "rcon-cli not installed or path incorrect"
fi

############################
# Start backup (single RCON session)
############################

log "Backup started"

mc_batch "
say §6[Backup] §eAutomatic backup starting...
save-all flush
" || fatal "Failed to flush world data"

sleep 5

############################
# Create hourly backup
############################

BACKUPFILE="$HOURLY/world_$NOW.tar.gz"

pax -w -z -f "$BACKUPFILE" "$WORLD" 2> "$BACKUPROOT/pax_error.log"
PAX_STATUS=$?

if [ ! -s "$BACKUPFILE" ]; then
    fatal "Failed to create backup archive: $(cat "$BACKUPROOT/pax_error.log")"
fi

[ $PAX_STATUS -ne 0 ] && log "WARNING: pax completed with warnings"

checksum_file "$BACKUPFILE"
log "Hourly backup created: $BACKUPFILE"
purge_old_backups "$HOURLY" "$RETAIN_HOURLY"

############################
# Daily backup at midnight
############################

if [ "$(date +%H)" = "00" ]; then
    DAILY_FILE="$DAILY/world_$NOW.tar.gz"
    cp "$BACKUPFILE" "$DAILY_FILE"
    cp "$BACKUPFILE.sha256" "$DAILY_FILE.sha256"

    log "Daily backup created: $DAILY_FILE"
    purge_old_backups "$DAILY" "$RETAIN_DAILY"
fi

############################
# Weekly backup (Sunday 02:00)
############################

if [ "$(date +%u)" = "7" ] && [ "$(date +%H)" = "02" ]; then
    BACKUPFILE="$WEEKLY/world_$NOW.tar.gz"

    pax -w -z -f "$BACKUPFILE" "$WORLD" 2> "$BACKUPROOT/pax_error.log"
    PAX_STATUS=$?

    if [ ! -s "$BACKUPFILE" ]; then
        fatal "Failed to create weekly backup: $(cat "$BACKUPROOT/pax_error.log")"
    fi

    [ $PAX_STATUS -ne 0 ] && log "WARNING: pax completed with warnings"

    checksum_file "$BACKUPFILE"
    log "Weekly backup created: $BACKUPFILE"
    purge_old_backups "$WEEKLY" "$RETAIN_WEEKLY"

    ICLOUD_FILE="$ICLOUD_WEEKLY/$(basename "$BACKUPFILE")"
    cp "$BACKUPFILE" "$ICLOUD_FILE"
    cp "$BACKUPFILE.sha256" "$ICLOUD_FILE.sha256"

    log "Weekly backup synced to iCloud: $ICLOUD_FILE"
    purge_old_icloud_backups "$ICLOUD_WEEKLY" "$ICLOUD_RETAIN_WEEKLY"
fi

############################
# Monthly backup (1st at 02:00)
############################

if [ "$(date +%d)" = "01" ] && [ "$(date +%H)" = "02" ]; then
    MONTHLY_FILE="$MONTHLY/world_$NOW.tar.gz"
    cp "$BACKUPFILE" "$MONTHLY_FILE"
    cp "$BACKUPFILE.sha256" "$MONTHLY_FILE.sha256"

    log "Monthly backup created: $MONTHLY_FILE"
    purge_old_backups "$MONTHLY" "$RETAIN_MONTHLY"
fi

############################
# Finish (single RCON session)
############################

mc_batch "say §a[Backup] Backup complete!" || true
