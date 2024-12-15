#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2024-forever paoliniluis
# Author: paoliniluis (paoliniluis)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
                                                                                                    
                                                 ...                                                
                                                .....                                               
                                                 ..                                                 
                                                                                                    
                                    =++=  ....  ....  ....  .+++:                                   
                                   .++++  ....  ..... ..... :+++=                                   
                                                              .                                     
                                    .==.  .-=.   ...   -=:   :=-                                    
                                   .++++  ++++. ..... =+++- :+++=                                   
                                    .+=.  .++:   ...   =+-   -+=                                    
                                     ..          ..           .                                     
                                   .++++  ....  =+++: ....  :+++=                                   
                                    =++=  ....  -+++. ....  .+++:                                   
                                                                                                    
                                    =++=  ....  ....   ...  .+++:                                   
                                   .++++  ....  ..... ..... :+++=                                   
                                     ..                      ...                                    
                                                 ..                                                 
                                                .....                                               
                                                 ...                                                
                                                                                                    
EOF
}
header_info
echo -e "Loading..."
APP="Metabase"
var_disk="2"
var_cpu="1"
var_ram="1024"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /home/metabase/ ]]; then 
  msg_error "No ${APP} Installation Found!"
  msg_info "Installing Dependencies"
  apt-get update && apt-get install -y curl sudo mc
  wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb && sudo dpkg -i jdk-21_linux-x64_bin.deb
  msg_ok "Installed Dependencies"

  msg_info "Installing Metabase"
  mkdir /home/metabase && wget https://downloads.metabase.com/latest/metabase.jar -O /home/metabase/metabase.jar
  msg_ok "Downloaded Metabase"

  msg_info "Setting up Metabase"
  sudo groupadd -r metabase && sudo useradd -r -s /bin/false -g metabase metabase
  sudo chown -R metabase:metabase /home/metabase/ && sudo touch /etc/default/metabase && sudo chmod 640 /etc/default/metabase

cat <<EOF > /etc/systemd/system/metabase.service
  [Unit]
  Description=Metabase server
  After=network.target

  [Service]
  WorkingDirectory=/home/metabase/
  ExecStart=/usr/bin/java --add-opens java.base/java.nio=ALL-UNNAMED -jar /home/metabase/metabase.jar
  EnvironmentFile=/etc/default/metabase
  User=metabase
  Type=simple
  SuccessExitStatus=143
  TimeoutStopSec=120
  Restart=always

  [Install]
  WantedBy=multi-user.target
EOF

  msg_info "Setting up PostgreSQL"
  apt-get install -y postgresql
  MB_DB_DBNAME=metabase
  MB_DB_USER=metabase
  MB_DB_PASS=metabase
  sudo -u postgres psql -c "CREATE ROLE $MB_DB_USER WITH LOGIN PASSWORD '$MB_DB_PASS';"
  sudo -u postgres psql -c "CREATE DATABASE $MB_DB_DBNAME WITH OWNER $MB_DB_USER"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $MB_DB_DBNAME TO $MB_DB_USER"
  msg_ok "Set up PostgreSQL"

cat <<EOF > /etc/default/metabase
  MB_DB_TYPE=postgres
  MB_DB_DBNAME=$MB_DB_DBNAME
  MB_DB_PORT=5432
  MB_DB_USER=$MB_DB_USER
  MB_DB_PASS=$MB_DB_PASS
  MB_DB_HOST=localhost
  MB_EMOJI_IN_LOGS=false
EOF

  msg_info "Starting Services"
  sudo systemctl daemon-reload && sudo systemctl start metabase.service
  msg_ok "Started Services"

  msg_info "Cleaning up"
  apt-get -y autoremove
  apt-get -y autoclean
  msg_ok "Cleaned"; 
  exit
  else
  msg_info "Updating ${APP}"
  msg_info "Stopping ${APP}"
  systemctl stop metabase
  msg_ok "Stopped ${APP}"

  rm /home/metabase/metabase.jar
  wget -O https://downloads.metabase.com/latest/metabase.jar -O /home/metabase/metabase.jar
  exit
  fi
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:3000${CL} \n"
