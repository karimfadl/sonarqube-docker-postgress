#!/bin/bash

# Set variables
BACKUP_DIR="/srv/sonarqube" # Local backup directory
S3_BUCKET="s3://kf-sonarqube-backup" # Your S3 bucket name
DAYS_TO_KEEP=15

# 1. Loop over each Docker volume
for VOLUME in $(docker volume ls -q); do
    TIMESTAMP=$(date +%d-%m-%y)
    BACKUP_NAME="${VOLUME}_${TIMESTAMP}.tar.gz"

    # 2. Create a backup of the volume
    rm -rf ${BACKUP_DIR}/${TIMESTAMP}
    mkdir -p ${BACKUP_DIR}/${TIMESTAMP}/${VOLUME}
    CONTAINER_ID=$(docker run -d -v ${VOLUME}:/volume busybox true)
    docker cp ${CONTAINER_ID}:/volume ${BACKUP_DIR}/${TIMESTAMP}/${VOLUME}
    docker rm -v ${CONTAINER_ID}

    # 3. Compress the backup
    tar -czf ${BACKUP_DIR}/${TIMESTAMP}/${BACKUP_NAME} -C ${BACKUP_DIR} ${TIMESTAMP}
    rm -rf ${BACKUP_DIR}/${TIMESTAMP}/${VOLUME}

    # 4. Create a backup of DB as Sql File
    docker exec db pg_dump -U sonar -d sonarqube > ${BACKUP_DIR}/${TIMESTAMP}/sonar-postgres-${TIMESTAMP}.sql

    # 5. Upload the compressed backup to an S3 bucket
    aws s3 cp ${BACKUP_DIR}/${TIMESTAMP}/${BACKUP_NAME} ${S3_BUCKET}/${TIMESTAMP}/${BACKUP_NAME}
    aws s3 cp ${BACKUP_DIR}/${TIMESTAMP}/sonar-postgres-${TIMESTAMP}.sql ${S3_BUCKET}/${TIMESTAMP}/sonar-postgres-${TIMESTAMP}.sql
done

# 5. Remove local backups older than 30 days
find ${BACKUP_DIR}/* -mtime +${DAYS_TO_KEEP} -exec rm -rf {} \;

# 6. Remove S3 backups older than 30 days
OLDER_THAN_DATE=$(date -d "-${DAYS_TO_KEEP} days" +%Y%m%d)
aws s3 ls ${S3_BUCKET}/ | awk '{print $4}' | while read BACKUP; do
    BACKUP_DATE=$(echo ${BACKUP} | awk -F_ '{print $2}' | awk -F. '{print $1}')
    if [[ ${BACKUP_DATE} -lt ${OLDER_THAN_DATE} ]]; then
        aws s3 rm ${S3_BUCKET}/${BACKUP}
    fi
done
