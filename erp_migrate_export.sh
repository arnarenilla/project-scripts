#!/bin/bash

DATE=$(date +%F)
BACKUP_DIR=~/erpnext-backups

REMOTE_USER="mis"
REMOTE_HOST="NEW_SERVER_IP"
REMOTE_DIR="~/erp-migration"

DB_CONTAINER="frappe_docker-db-1"
SITE_CONTAINER="frappe_docker-backend-1"

DBS=(
  "_160b1753e4a05e00"
  "_16be1997f7bdf334"
)

mkdir -p "$BACKUP_DIR"

echo "🚀 Creating backup..."

# DB backup
for DB in "${DBS[@]}"; do
  docker exec "$DB_CONTAINER" sh -c \
  "mysqldump -u root -p\$MYSQL_ROOT_PASSWORD $DB" \
  | gzip > "$BACKUP_DIR/db_${DB}_$DATE.sql.gz"
done

# Site backup
docker exec "$SITE_CONTAINER" tar czf - /home/frappe/frappe-bench/sites \
> "$BACKUP_DIR/sites_$DATE.tar.gz"

echo "📤 Sending to new server..."

ssh $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR"

scp $BACKUP_DIR/*_$DATE.* $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

echo "✅ Migration export complete"
