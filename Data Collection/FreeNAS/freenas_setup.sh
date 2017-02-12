#!/bin/bash
#
# FreeNAS Graphite & HDD_Temps Setup

# Determine which user is logged in
USER=$(whoami)

# Collect Information

echo -e "\e[7mWelcome to the setup script for FreeNAS System Information and Drive Temps. This script will ask for some data and create all the necessary files to get you up and running! \e[0m"

echo
echo

echo -n "Press any key to continue"
read -rsn1

echo
echo

echo -e "\e[7mWhere would you like the script and config files place? Please us the full path. (Example: /home/$USER/scripts/freenas/) \e[0m"
read -p "> " DIR

echo

echo -e "\e[7mWhat is the name of your FreeNAS host? This is what your host will be displayed as in Grafana. \e[0m"
read -p "> " HOST

echo

echo -e "\e[7mWhat is the IP of your FreeNAS host? \e[0m"
read -p "> " FREENASIP

echo

echo -e "\e[7mWhat is the root username for your FreeNAS host? \e[0m"
read -p "> " ROOT

echo

echo -e "\e[7mWhat is the root password for your FreeNAS host? \e[0m"
read -p "> " -s PASSWORD

echo
echo

echo -e "\e[7mWhat is the complete IP of your InfluxDB? Must include the port. InfluxDB's default port is 8086.  (Example: 10.10.10.100:8086) \e[0m"
read -p "> " INFLUXIP

echo

echo -e "\e[7mWhat is the name of the database you'd like to use? If the database does not exist, it will be automatically created. \e[0m"
read -p "> " DATABASE

echo

echo -e "\e[7mHow often would you like the script to poll your ESXi host? (In seconds) \e[0m"
read -p "> " INTERVAL

echo -e "\e[7mWhich drives do you want to monitor? (Seperate drives with a space) \e[0m"
read -p "> " DRIVES

clear

# Ensure directory exists
echo -e "\e[36mVerifying Directory Status \e[0m"

if [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
fi >/dev/null 2>&1

# Create Harddrive Temp config file
echo -e "\e[36mGenerating Drive Temps Configuration File \e[0m"

cat >$DIR"drivetemps.cfg"<<EOF >/dev/null 2>&1
########################################
#                                      #
# Configuration File for drivetemps.sh #
#                                      #
# Created by github.com/tylerhammer    #
#                                      #
########################################

# FreeNAS Host IP
FREENASIP=${FREENASIP}

# FreeNAS Root Username
ROOT=${ROOT}

# FreeNAS Root Password
PASSWORD=${PASSWORD}

# Interval between polls (In seconds)
INTERVAL=${INTERVAL}

EOF

# Download drivetemps.sh
echo -e "\e[36mDownloading Drive Temps script file \e[0m"
wget -O $DIR"drivetemps.sh" https://raw.githubusercontent.com/tylerhammer/grafana/master/Data%20Collection/FreeNAS/drivetemps.sh >/dev/null 2>&1

# Update drivetemps.sh with config file.
echo -e "\e[36mConnecting Configuration file and Drive Temps script \e[0m"
sed -i "4i . "$DIR"drivetemps.cfg" $DIR"drivetemps.sh" >/dev/null 2>&1

# Set Chmod
echo -e "\e[36mUpdating permissions \e[0m"
chmod +x $DIR"drivetemps.sh"

# Create DATABASE
echo -e "\e[36mCreating database in InfluxDB \e[0m"
curl -i -XPOST "http://$INFLUXIP/query" --data-urlencode "q=CREATE DATABASE $DATABASE" >/dev/null 2>&1

# Create SystemD file
echo -e "\e[36mCreating SystemD file \e[0m"
sudo bash -c "cat >/lib/systemd/system/drivetemps.service" <<EOF >/dev/null 2>&1
[Unit]
Description=Drive Temps
Requires=influxdb.service
After=influxdb.service

[Service]
Type=simple
User=$USER
ExecStart=/bin/bash -x $DIR"drivetemps.sh"

[Install]
WantedBy=default.target
EOF


# SSH into host
echo -e "\e[36mAccessing FreeNAS host\e[0m"
sshpass -p ${PASSWORD} ssh ${ROOT}@${FREENASIP} <<EOF


# Create Directory
echo "Creating required directory"
mkdir -p /root/scripts/
cd /root/scripts/

# Downloading hdd_temp.sh
echo "Downloading HDD Temp script file"
wget -O /root/scripts/hdd_temp.sh https://raw.githubusercontent.com/tylerhammer/grafana/master/Data%20Collection/FreeNAS/hdd_temp.sh

# Generate Config File
echo "Generating HDD Temp Configuration File"
cat >/root/scripts/hdd_temp.cfg<<DOF
########################################
#                                      #
# Configuration File for drivetemps.sh #
#                                      #
# Created by github.com/tylerhammer    #
#                                      #
########################################

# FreeNAS Host IP
INFLUXIP=${INFLUXIP}

# Database Name
DATABASE=${DATABASE}

# FreeNAS Host Name
Host=${HOST}

# Drives being montiroed
DRIVES="${DRIVES}"
DOF

# Set Chmod
echo "Updating permissions"
chmod +x /root/scripts/hdd_temp.sh

exit

EOF

echo -e "\e[36mDisconnecting from FreeNAS host \e[0m"

# Enable SystemD service
echo -e "\e[36mEnabling Services \e[0m"
systemctl enable drivetemps.service >/dev/null 2>&1
systemctl start drivetemps.service >/dev/null 2>&1

clear

# Finishing thoughts
echo -e "\e[7mCongradulations, the FreeNAS setup script has successfully completed and you should start seeing data in Influx. \e[0m"
echo -e "\e[7mShould you have any other questions or suggestions, please reach out to me at git@tylerhammer.com or on Discord Hammer#4341. \e[0m"
echo
