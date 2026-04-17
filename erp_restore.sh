#!/bin/bash

BACKUP_DIR=~/erpnext-backups

DB_CONTAINER="frappe_docker-db-1"
BACKEND_CONTAINER="frappe_docker-backend-1"
FRONTEND_CONTAINER="frappe_docker-frontend-1"
WS_CONTAINER="frappe_docker-websocket-1"

DATE=$1

if [ -z "$DATE" ]; then
  echo "❌ Usage: ./restore.sh YYYY-MM-DD"
  exit 1
fi

echo "⚠️ Starting ERPNext restore for: $DATE"
echo "========================================"

DBS=(
  "_160b1753e4a05e00"
  "_16be1997f7bdf334"
)

# =========================
# 1. RESTORE DATABASES
# =========================
for DB_NAME in "${DBS[@]}"; do

  FILE="$BACKUP_DIR/db_${DB_NAME}_$DATE.sql.gz"

  if [ ! -f "$FILE" ]; then
    echo "❌ Missing file: $FILE"
    continue
  fi

  echo "📦 Restoring DB: $DB_NAME"

  gunzip -c "$FILE" | docker exec -i "$DB_CONTAINER" \
  mysql -u root -padmin "$DB_NAME"

  if [ $? -eq 0 ]; then
    echo "✅ Restored: $DB_NAME"
  else
    echo "❌ Failed: $DB_NAME"
  fi

done

# =========================
# 2. RESTORE FILES
# =========================
SITE_FILE="$BACKUP_DIR/sites_$DATE.tar.gz"

if [ -f "$SITE_FILE" ]; then
  echo "📁 Restoring site files..."

  docker exec -i "$BACKEND_CONTAINER" sh -c \
  "tar xzf - -C /" < "$SITE_FILE"

  echo "✅ Site files restored"
else
  echo "❌ Site backup missing"
fi

# =========================
# 3. SAFE START ORDER (IMPORTANT FIX)
# =========================

echo "🔄 Restarting services in correct order..."

echo "➡️ Starting DB..."
docker restart $DB_CONTAINER
sleep 10

echo "➡️ Starting Backend..."
docker restart $BACKEND_CONTAINER
sleep 20

echo "➡️ Starting Websocket..."
docker restart $WS_CONTAINER
sleep 10

echo "➡️ Starting Frontend (NGINX)..."
docker restart $FRONTEND_CONTAINER
sleep 15

# =========================
# 4. FINAL HEALTH CHECK
# =========================

echo "🧪 Running health check..."

docker exec -it $BACKEND_CONTAINER \
bench --site site1.local doctor

echo "🎉 RESTORE COMPLETE"
