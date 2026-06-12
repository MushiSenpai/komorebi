#!/usr/bin/env bash
# Nightly Komorebi Arena backup: consistent pb_data snapshot -> Storage Box.
# Brief service stop keeps the sqlite copy consistent (~seconds of downtime).
set -euo pipefail
STAMP=$(date -u +%Y%m%d)
DEST=/var/backups/arena
systemctl stop pocketbase
tar -czf "$DEST/arena-pb_data-$STAMP.tar.gz" -C /opt/pocketbase pb_data
systemctl start pocketbase
# Keep 14 local dailies; mirror the folder (with deletions) offsite.
find "$DEST" -name 'arena-pb_data-*.tar.gz' -mtime +14 -delete
rsync -a --delete -e ssh "$DEST/" storagebox:./arena-backups/
logger -t arena-backup "ok: $(ls "$DEST" | wc -l) snapshots, latest arena-pb_data-$STAMP.tar.gz"
