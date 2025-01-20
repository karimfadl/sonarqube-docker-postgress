#!/bin/bash
# To Use This script, pass BACKUP_DATE in the format "day-month-year", e.g., "27-03-24".
echo -n "The BACKUP_DATE IS: "
read BACKUP_DATE

# Variables
BACKUP_DIR="/srv/sonarqube/$BACKUP_DATE"
S3_BUCKET="s3://kf-sonarqube-backup"

# Download the backup volumes from S3 to the local backup directory
echo "Downloading backup volumes from $S3_BUCKET to $BACKUP_DIR..."
rm -rf $BACKUP_DIR
sudo aws s3 sync $S3_BUCKET/$BACKUP_DATE $BACKUP_DIR

# Shutdown application-related containers (but keep the database container running)
echo "Shutting down application-related containers..."
cd /home/ec2-user/sonarqube-docker-postgress
docker-compose down --remove-orphans

# Restore all other volumes
echo "Restoring Docker volumes..."
for VOLUME in sonarqube-docker-postgress_postgresql_data sonarqube-docker-postgress_sonarqube_conf sonarqube-docker-postgress_sonarqube_data sonarqube-docker-postgress_sonarqube_extensions sonarqube-docker-postgress_sonarqube_logs; do
    VOLUME_BACKUP_DIR="$BACKUP_DIR/$VOLUME"
    VOLUME_BACKUP_FILE="$VOLUME_BACKUP_DIR/${VOLUME}_${BACKUP_DATE}.tar.gz"

    echo "Restoring $VOLUME..."
    docker run --rm --mount source=$VOLUME,target=/volume -v $VOLUME_BACKUP_DIR:/backup busybox tar -xzvf /backup/${VOLUME}_${BACKUP_DATE}.tar.gz -C /volume
    docker run -i --mount source=$VOLUME,target=/volume busybox sh -c "cd /volume; chmod -R 777 /volume"
done

# Restore DB Data Volume
echo "Starting database container for restore..."
docker-compose up -d db
sleep 30

echo "Drop Sonarqube DB Tables..."
docker exec db psql -U sonar -d sonarqube -c "
DO
\$\$
BEGIN
  EXECUTE (
    SELECT string_agg('DROP TABLE IF EXISTS ' || tablename || ' CASCADE;', ' ')
    FROM pg_tables
    WHERE schemaname = 'public'
  );
END
\$\$;"

echo "Restoring DB Data SQL..."
DB_BACKUP="$BACKUP_DIR/db/sonar-postgres-$BACKUP_DATE.sql"
docker exec -i db psql -U sonar -d sonarqube --set ON_ERROR_STOP=on --single-transaction < $DB_BACKUP

echo "Stopping database container..."
docker-compose stop db

# Start all containers
echo "Starting all containers..."
docker-compose up -d

# Delete ES indexes
echo "Deleting ES indexes..."
docker exec -it sonarqube bash
rm -rf data/es8/*
exit
docker-compose down
docker-compose up -d

echo "Restore completed successfully."
