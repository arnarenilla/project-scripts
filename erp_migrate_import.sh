#!/bin/bash

DATE=$1
BACKUP_DIR=~/erp-migration

DB_CONTAINER="frappe_docker-db-1"
BACKEND_CONTAINER="frappe_docker-backend-1"
FRONTEND_CONTAINER="frappe_docker-frontend-1"
WS_CONTAINER="frappe_docker-websocket-1"

DBS=(
  "_160b1753e4a05e00"
  "_16be1997f7bdf334"
)

if [ -z "$DATE" ]; then
  echo "❌ Usage: ./migrate_import.sh YYYY-MM-DD"
  exit 1
fi

echo "⚠️ Starting restore on new server..."

# =========================
# RESTORE DATABASES
# =========================
for DB in "${DBS[@]}"; do

  FILE="$BACKUP_DIR/db_${DB}_$DATE.sql.gz"

  if [ -f "$FILE" ]; then
    echo "📦 Restoring $DB"
    gunzip -c "$FILE" | docker exec -i "$DB_CONTAINER" \
    mysql -u root -padmin "$DB"
  else
    echo "❌ Missing $FILE"
  fi

done

# =========================
# RESTORE FILES
# =========================
SITE_FILE="$BACKUP_DIR/sites_$DATE.tar.gz"

if [ -f "$SITE_FILE" ]; then
  echo "📁 Restoring site files"
  docker exec -i "$BACKEND_CONTAINER" sh -c \
  "tar xzf - -C /" < "$SITE_FILE"
fi

# =========================
# FIX DB USER (IMPORTANT)
# =========================
echo "🔧 Fixing DB access..."

docker exec -it "$DB_CONTAINER" mysql -u root -padmin -e "
DROP USER IF EXISTS '_16be1997f7bdf334'@'%';
CREATE USER '_16be1997f7bdf334'@'%' IDENTIFIED BY 'erp123';
GRANT ALL PRIVILEGES ON _16be1997f7bdf334.* TO '_16be1997f7bdf334'@'%';
FLUSH PRIVILEGES;
"

# =========================
# START SERVICES IN ORDER
# =========================
echo "🔄 Starting services..."

docker restart $DB_CONTAINER
sleep 10

docker restart $BACKEND_CONTAINER
sleep 20

docker restart $WS_CONTAINER
sleep 10

docker restart $FRONTEND_CONTAINER
sleep 15

# =========================
# FINAL FIX
# =========================
docker exec -it $BACKEND_CONTAINER \
bench --site site1.local migrate

echo "🎉 Migration complete!"
