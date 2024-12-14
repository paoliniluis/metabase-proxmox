#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: Luis Paolini (paoliniluis)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc
$STD wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb && sudo dpkg -i jdk-21_linux-x64_bin.deb

msg_ok "Installed Dependencies"

msg_info "Installing Metabase"
$STD mkdir /home/metabase && wget -q https://downloads.metabase.com/latest/metabase.jar
msg_ok "Downloaded Metabase"

msg_info "Setting up Metabase"
$STD sudo groupadd -r metabase \
sudo useradd -r -s /bin/false -g metabase metabase \
sudo chown -R metabase:metabase /home/metabase.jar \
sudo touch /var/log/metabase.log \
sudo chown syslog:adm /var/log/metabase.log \
sudo touch /etc/default/metabase \
sudo chmod 640 /etc/default/metabase

$STD cat <<EOF > /etc/systemd/system/metabase.service
[Unit]
Description=Metabase server
After=syslog.target
After=network.target

[Service]
WorkingDirectory=</your/path/to/metabase/directory/>
ExecStart=/usr/bin/java --add-opens java.base/java.nio=ALL-UNNAMED -jar </your/path/to/metabase/directory/>metabase.jar
EnvironmentFile=/etc/default/metabase
User=metabase
Type=simple
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=metabase
SuccessExitStatus=143
TimeoutStopSec=120
Restart=always

[Install]
WantedBy=multi-user.target
EOF

$STD sudo touch /etc/rsyslog.d/metabase.conf
$STD cat <<EOF > /etc/rsyslog.d/metabase.conf
if $programname == 'metabase' then /var/log/metabase.log
& stop
EOF

msg_info "Setting up PostgreSQL"
$STD apt-get install -y postgresql
MB_DB_DBNAME=metabase
MB_DB_USER=metabase
MB_DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER"
msg_ok "Set up PostgreSQL"

$STD cat <<EOF > /etc/default/metabase
MB_DB_TYPE=postgres
MB_DB_DBNAME=$MB_DB_DBNAME
MB_DB_PORT=5432
MB_DB_USER=$MB_DB_USER
MB_DB_PASS=$MB_DB_PASS
MB_DB_HOST=localhost
MB_EMOJI_IN_LOGS=false
EOF

msg_info "Starting Services"
$STD sudo systemctl restart rsyslog.service \
sudo systemctl daemon-reload
sudo systemctl start metabase.service
msg_ok "Started Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
