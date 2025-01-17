#!/bin/bash
#To Use This script you must pass BACKUP_DATE and it should be "day-month-year, exp:"27-03-24").
echo -n "The BACKUP_DATE IS: "
read BACKUP_DATE

#Download The Backup volumes from kf-sonarqube-backup S3 Bucket under /srv/sonarqube/
echo "Downloading.... Backup volumes from kf-sonarqube-backup S3 Bucket under /srv/sonarqube/"
rm -rf /srv/sonarqube/$BACKUP_DATE
sudo aws s3 sync s3://kf-sonarqube-backup/$BACKUP_DATE /srv/sonarqube/$BACKUP_DATE

#Shutdown all containers
echo "Shutdown.... all containers"
cd /home/ec2-user/sonarqube-docker
docker-compose down

#Restore DB Data Volume
echo "Restoring.... DB Data Volume"
docker run --rm --mount source=kf-sonarqube_postgresql_data,target=/var/lib/postgresql/data -v /srv/sonarqube/$BACKUP_DATE/:/backup busybox tar -xzvf /backup/kf-sonarqube_postgresql_data_$BACKUP_DATE.tar.gz -C /var/lib/postgresql/data
docker run -i --mount source=kf-sonarqube_postgresql_data,target=/var/lib/postgresql/data busybox sh -c "cd /var/lib/postgresql/data/; rm -rf PG_VERSION global/ base/ pg_* post*; mv $BACKUP_DATE/kf-sonarqube_postgresql_data/volume/* .; rm -rf $BACKUP_DATE/"

#Restore SQ Config Volume
echo "Restoring.... SQ Config Volume"
docker run --rm --mount source=kf-sonarqube_sonarqube_conf,target=/opt/sonarqube/conf -v /srv/sonarqube/$BACKUP_DATE/:/backup busybox tar -xzvf /backup/kf-sonarqube_sonarqube_conf_$BACKUP_DATE.tar.gz -C /opt/sonarqube/conf
docker run -i --mount source=kf-sonarqube_sonarqube_conf,target=/opt/sonarqube/conf busybox sh -c "cd /opt/sonarqube/conf; rm -rf sonar.properties; mv $BACKUP_DATE/kf-sonarqube_sonarqube_conf/volume/* .; rm -rf $BACKUP_DATE/; chmod -R 777 /opt/sonarqube/conf"

#Restore SQ Data Volume
echo "Restoring.... SQ Data Volume"
docker run --rm --mount source=kf-sonarqube_sonarqube_data,target=/opt/sonarqube/data -v /srv/sonarqube/$BACKUP_DATE/:/backup busybox tar -xzvf /backup/kf-sonarqube_sonarqube_data_$BACKUP_DATE.tar.gz -C /opt/sonarqube/data
docker run -i --mount source=kf-sonarqube_sonarqube_data,target=/opt/sonarqube/data busybox sh -c "cd /opt/sonarqube/data; rm -rf README.txt es8/ sonar.mv.db web/; mv $BACKUP_DATE/kf-sonarqube_sonarqube_data/volume/* .; rm -rf $BACKUP_DATE/; chmod -R 777 /opt/sonarqube/data"

#Restore SQ Extension Volume
echo "Restoring.... SQ Extension Volume"
docker run --rm --mount source=kf-sonarqube_sonarqube_extensions,target=/opt/sonarqube/extensions -v /srv/sonarqube/$BACKUP_DATE/:/backup busybox tar -xzvf /backup/kf-sonarqube_sonarqube_extensions_$BACKUP_DATE.tar.gz -C /opt/sonarqube/extensions
docker run -i --mount source=kf-sonarqube_sonarqube_extensions,target=/opt/sonarqube/extensions busybox sh -c "cd /opt/sonarqube/extensions; rm -rf downloads/ jdbc-driver/ plugins/; mv $BACKUP_DATE/kf-sonarqube_sonarqube_extensions/volume/* .; rm -rf $BACKUP_DATE/; chmod -R 777 /opt/sonarqube/extensions/"

#Restore SQ Logs Volume
echo "Restoring.... SQ Logs Volume"
docker run --rm --mount source=kf-sonarqube_sonarqube_logs,target=/opt/sonarqube/logs -v /srv/sonarqube/$BACKUP_DATE/:/backup busybox tar -xzvf /backup/kf-sonarqube_sonarqube_logs_$BACKUP_DATE.tar.gz -C /opt/sonarqube/logs
docker run -i --mount source=kf-sonarqube_sonarqube_logs,target=/opt/sonarqube/logs busybox sh -c "cd /opt/sonarqube/logs/; rm -rf README.txt *.log; mv $BACKUP_DATE/kf-sonarqube_sonarqube_logs/volume/* .; rm -rf 28-03-24/; chmod -R 777 /opt/sonarqube/logs/"

#Finally Run All Containers
echo "Run.... all containers"
cd /home/ec2-user/sonarqube-docker
docker-compose up -d
