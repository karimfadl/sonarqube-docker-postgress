#!/bin/bash

cd /tmp || exit
echo "Downloading sonar-scanner....."
if [ -d "/tmp/sonar-scanner-cli-4.8.0.2856-linux.zip" ];then
    sudo rm /tmp/sonar-scanner-cli-4.8.0.2856-linux.zip
fi
curl https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip --output sonar-scanner-cli-4.8.0.2856-linux.zip
echo "Download completed."

echo "Unziping downloaded file..."
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
echo "Unzip completed."
rm sonar-scanner-cli-4.8.0.2856-linux.zip

echo "Installing to opt..."
if [ -d "/opt/sonar-scanner-4.8.0.2856-linux" ];then
    sudo rm -rf /opt/sonar-scanner-4.8.0.2856-linux
fi
sudo mv sonar-scanner-4.8.0.2856-linux /opt/sonar-scanner

echo "Installation completed successfully."

echo "You can use sonar-scanner!"
