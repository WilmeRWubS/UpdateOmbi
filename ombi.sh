#!/bin/bash

# === CONFIGURATIE ===
SERVICE_NAME="ombi"
OMBI_USER="ombi"
OMBI_GROUP="nogroup"
OMBI_URL="https://github.com/Ombi-app/Ombi/releases"
OMBI_TAGS_URL="https://github.com/Ombi-app/Ombi/tags"
DOWNLOAD_NAME="linux-x64.tar.gz"
WORKING_DIR="/opt/Ombi"
STORAGE_DIR="/etc/Ombi"
BACKUP_DIR_NEW="/opt/ombi-backup"
BACKUP_DIR_OLD="/opt/ombi-backup-old"
LOG_DIR="/opt/Logs"
SLACK_WEBHOOK=""
DISCORD_WEBHOOK=""
SUPPRESS_OUTPUT="no"

# === INIT ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/ombi_update_log_$TIMESTAMP.txt"
mkdir -p "$LOG_DIR"

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") $1" | tee -a "$LOG_FILE"
}

# === VERSIEDETECTIE ===
VERSION=$(curl -s "https://api.github.com/repos/Ombi-app/Ombi/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d 'v')
[ -z "$VERSION" ] && log "[ERROR] Kan nieuwste versie niet ophalen." && exit 1
log "[INFO] Nieuwste versie gevonden: $VERSION"

INSTALLED=$(strings "$WORKING_DIR/Ombi" 2>/dev/null | grep -Po 'Ombi/\d+\.\d+\.\d+' | cut -d/ -f2 | sort -V | tail -1)
[ -z "$INSTALLED" ] && log "[ERROR] Geïnstalleerde versie niet gevonden." && exit 1
log "[INFO] Geïnstalleerde versie: $INSTALLED"

if [ "$VERSION" = "$INSTALLED" ]; then
    log "[INFO] OMBI is al up-to-date."
    exit 0
fi

# === UPGRADE BEVESTIGING ===
echo ""
echo "=========================================="
echo "OMBI UPDATE BESCHIKBAAR"
echo "=========================================="
echo "Huidige versie:  v$INSTALLED"
echo "Nieuwe versie:   v$VERSION"
echo "=========================================="
echo ""
read -p "Wilt u doorgaan met de update? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "[INFO] Update geannuleerd door gebruiker."
    exit 0
fi

log "[INFO] Update bevestigd door gebruiker. Start update proces..."

# === STOP DIENST ===
log "[INFO] Stopt $SERVICE_NAME..."
systemctl stop "$SERVICE_NAME" || { log "[ERROR] Kon $SERVICE_NAME niet stoppen."; exit 1; }

# === BACKUPS ===
log "[INFO] Verwijdert oude backup..."
rm -rf "$BACKUP_DIR_OLD"
cp -r "$BACKUP_DIR_NEW" "$BACKUP_DIR_OLD"

log "[INFO] Maakt nieuwe backup..."
rm -rf "$BACKUP_DIR_NEW"
cp -r "$WORKING_DIR" "$BACKUP_DIR_NEW"

# === DOWNLOAD ===
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

log "[INFO] Downloadt OMBI v$VERSION..."
wget -q "$OMBI_URL/download/v$VERSION/$DOWNLOAD_NAME" || { log "[ERROR] Download mislukt."; exit 1; }

log "[INFO] Pakt archief uit..."
tar -xzf "$DOWNLOAD_NAME"

# === INSTALLATIE ===
log "[INFO] Vervangt oude installatie..."
rm -rf "$WORKING_DIR"
mv "$TMP_DIR" "$WORKING_DIR"

# === DATABASE HERSTEL (optioneel) ===
for DB_FILE in Ombi.db OmbiSettings.db OmbiExternal.db database.json; do
    if [ -f "$STORAGE_DIR/$DB_FILE" ]; then
        cp "$STORAGE_DIR/$DB_FILE" "$WORKING_DIR/"
        log "[INFO] Hersteld $DB_FILE van STORAGE_DIR"
    elif [ -f "$BACKUP_DIR_NEW/$DB_FILE" ]; then
        cp "$BACKUP_DIR_NEW/$DB_FILE" "$WORKING_DIR/"
        log "[INFO] Hersteld $DB_FILE van BACKUP"
    fi
done

# === BESTANDSRECHTEN ===
chown -R "$OMBI_USER:$OMBI_GROUP" "$WORKING_DIR"
log "[INFO] Bestandsrechten toegepast voor $OMBI_USER"

# === DIENST HERSTARTEN ===
systemctl daemon-reload
systemctl start "$SERVICE_NAME"
log "[INFO] $SERVICE_NAME herstart."

# === MELDINGEN (optioneel) ===
MESSAGE="OMBI bijgewerkt van v$INSTALLED naar v$VERSION"

if [ -n "$SLACK_WEBHOOK" ]; then
    curl -s -X POST --data "payload={\"text\": \"$MESSAGE\"}" "$SLACK_WEBHOOK"
    log "[INFO] Slack melding verzonden."
fi

if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MESSAGE\"}" "$DISCORD_WEBHOOK"
    log "[INFO] Discord melding verzonden."
fi

log "[SUCCESS] Update naar v$VERSION voltooid!"

echo ""
echo "✅ OMBI succesvol bijgewerkt naar versie $VERSION"
echo "Logbestand: $LOG_FILE"
echo ""

exit 0