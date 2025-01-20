#!/bin/bash

# Set variables
BACKUP_DIR="/srv/sonarqube" # Local backup directory
S3_BUCKET="s3://kf-sonarqube-backup" # Your S3 bucket name
DAYS_TO_KEEP=15

# 1. Loop over each Docker volume
for VOLUME in $(docker volume ls -q); do
    TIMESTAMP=$(date +%d-%m-%y)
    BACKUP_VOLUME_DIR="${BACKUP_DIR}/${TIMESTAMP}/${VOLUME}" # Directory for this volume's backup
    BACKUP_NAME="${VOLUME}_${TIMESTAMP}.tar.gz"

    # 2. Create a backup of the volume
    mkdir -p ${BACKUP_VOLUME_DIR}
    CONTAINER_ID=$(docker run -d -v ${VOLUME}:/volume busybox true)
    docker cp ${CONTAINER_ID}:/volume ${BACKUP_VOLUME_DIR}
    docker rm -v ${CONTAINER_ID}

    # 3. Compress the backup and keep it in the volume's subdirectory
    tar -czf ${BACKUP_VOLUME_DIR}/${BACKUP_NAME} -C ${BACKUP_VOLUME_DIR} .
    rm -rf ${BACKUP_VOLUME_DIR}/volume # Remove uncompressed data after archiving

    # 4. Create a backup of DB as a SQL file in a separate directory
    DB_BACKUP_NAME="sonar-postgres-${TIMESTAMP}.sql"
    mkdir -p ${BACKUP_DIR}/${TIMESTAMP}/db
    docker exec db pg_dump -U sonar -d sonarqube > ${BACKUP_DIR}/${TIMESTAMP}/db/${DB_BACKUP_NAME}

    # 5. Upload the compressed backup and SQL dump to the S3 bucket
    aws s3 cp ${BACKUP_VOLUME_DIR}/${BACKUP_NAME} ${S3_BUCKET}/${TIMESTAMP}/${VOLUME}/${BACKUP_NAME}
    aws s3 cp ${BACKUP_DIR}/${TIMESTAMP}/db/${DB_BACKUP_NAME} ${S3_BUCKET}/${TIMESTAMP}/db/${DB_BACKUP_NAME}
done

# 6. Remove local backups older than 15 days
find ${BACKUP_DIR}/* -mtime +${DAYS_TO_KEEP} -exec rm -rf {} \;

# 7. Remove S3 backups older than 15 days
OLDER_THAN_DATE=$(date -d "-${DAYS_TO_KEEP} days" +%Y%m%d)
aws s3 ls ${S3_BUCKET}/ | awk '{print $4}' | while read BACKUP; do
    BACKUP_DATE=$(echo ${BACKUP} | awk -F_ '{print $2}' | awk -F. '{print $1}')
    if [[ ${BACKUP_DATE} -lt ${OLDER_THAN_DATE} ]]; then
        aws s3 rm ${S3_BUCKET}/${BACKUP}
    fi
done
