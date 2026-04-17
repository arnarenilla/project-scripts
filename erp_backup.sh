#!/bin/bash

DATE=$(date +%F)

DB_CONTAINER="frappe_docker-db-1"
SITE_CONTAINER="frappe_docker-backend-1"

# BOTH DATABASES
DBS=(
  "_160b1753e4a05e00"
  "_16be1997f7bdf334"
)

BACKUP_DIR=~/erpnext-backups
mkdir -p "$BACKUP_DIR"

echo "🚀 Starting ERPNext backup: $DATE"

# =========================
# 1. DATABASE BACKUP LOOP
# =========================
for DB_NAME in "${DBS[@]}"; do
  echo "📦 Backing up database: $DB_NAME"

  docker exec "$DB_CONTAINER" sh -c \
  "mysqldump -u root -p\$MYSQL_ROOT_PASSWORD $DB_NAME" \
  | gzip > "$BACKUP_DIR/db_${DB_NAME}_$DATE.sql.gz"

  if [ $? -eq 0 ]; then
    echo "✅ DB backup OK: $DB_NAME"
  else
    echo "❌ DB backup FAILED: $DB_NAME"
  fi
done

# =========================
# 2. FILES BACKUP
# =========================
echo "📁 Backing up site files..."

docker exec "$SITE_CONTAINER" tar czf - /home/frappe/frappe-bench/sites \
> "$BACKUP_DIR/sites_$DATE.tar.gz"

if [ $? -eq 0 ]; then
  echo "✅ Sites backup OK"
else
  echo "❌ Sites backup FAILED"
fi

echo "🎉 Backup completed: $DATE"
