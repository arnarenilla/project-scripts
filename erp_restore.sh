#!/bin/bash

BACKUP_DIR=~/erpnext-backups

DB_CONTAINER="frappe_docker-db-1"
SITE_CONTAINER="frappe_docker-backend-1"

DATE=$1

if [ -z "$DATE" ]; then
  echo "❌ Please provide backup date: ./restore.sh 2026-04-17"
  exit 1
fi

echo "⚠️ RESTORE STARTING for date: $DATE"
echo "THIS WILL OVERWRITE CURRENT DATA"

# =========================
# 1. RESTORE DATABASES
# =========================
DBS=(
  "_160b1753e4a05e00"
  "_16be1997f7bdf334"
)

for DB_NAME in "${DBS[@]}"; do

  FILE="$BACKUP_DIR/db_${DB_NAME}_$DATE.sql.gz"

  if [ ! -f "$FILE" ]; then
    echo "❌ Missing backup file: $FILE"
    continue
  fi

  echo "📦 Restoring DB: $DB_NAME"

  gunzip -c "$FILE" | docker exec -i "$DB_CONTAINER" \
  mysql -u root -padmin "$DB_NAME"

  if [ $? -eq 0 ]; then
    echo "✅ Restored: $DB_NAME"
  else
    echo "❌ Restore failed: $DB_NAME"
  fi

done

# =========================
# 2. RESTORE SITE FILES
# =========================
SITE_FILE="$BACKUP_DIR/sites_$DATE.tar.gz"

if [ -f "$SITE_FILE" ]; then
  echo "📁 Restoring site files..."

  docker exec -i "$SITE_CONTAINER" sh -c \
  "tar xzf - -C /" < "$SITE_FILE"

  echo "✅ Site files restored"
else
  echo "❌ Site backup not found: $SITE_FILE"
fi

# =========================
# 3. RESTART SYSTEM
# =========================
echo "🔄 Restarting containers..."

docker restart $SITE_CONTAINER $DB_CONTAINER

echo "🎉 RESTORE COMPLETED"
