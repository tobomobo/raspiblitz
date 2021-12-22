#!/usr/bin/env bash

# main repo: https://github.com/fusion44/blitz_api

# restart the systemd `blitzapi` when credentials of lnd or bitcoind are changeing and it will
# excute the `update-config` automatically before restarting

# TODO: On sd card install there might be no Bitcoin & Lightning confs - make sure backend runs without

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ]; then
  echo "Manage RaspiBlitz Web API"
  echo "blitz.web.api.sh on [?GITHUBUSER] [?REPO] [?BRANCH]"
  echo "blitz.web.api.sh update-config"
  echo "blitz.web.api.sh update-code"
  echo "blitz.web.api.sh off"
  exit 1
fi

DEFAULT_GITHUB_USER="fusion44"
DEFAULT_GITHUB_REPO="blitz_api"
DEFAULT_GITHUB_BRANCH="main"

###################
# ON / INSTALL
###################
if [ "$1" = "1" ] || [ "$1" = "on" ]; then

  if [ "$2" != "" ]; then
    DEFAULT_GITHUB_USER="$2"
  fi

  if [ "$3" != "" ]; then
    DEFAULT_GITHUB_REPO="$3"
  fi

  if [ "$4" != "" ]; then
    DEFAULT_GITHUB_BRANCH="$4"
  fi

  echo "# INSTALL Web API ..."
  
  # clean old code
  sudo rm -r /home/admin/blitz_api 2>/dev/null
  cd /home/admin

  # git clone https://github.com/fusion44/blitz_api.git /home/admin/blitz_api
  git clone https://github.com/${DEFAULT_GITHUB_USER}/${DEFAULT_GITHUB_REPO}.git /home/admin/blitz_api
  cd blitz_api
  git checkout ${DEFAULT_GITHUB_BRANCH}

  # 
  pip install -r requirements.txt

  # build the config and set unique secret (its OK to be a new secret every install/update)
  /home/admin/config.scripts/blitz.web.api.sh update-config

  # prepare systemd service
  echo "
[Unit]
Description=BlitzBackendAPI
Wants=background.scan.service
After=background.scan.service

[Service]
WorkingDirectory=/home/admin/blitz_api
# before every start update the config with latest credentials/settings
ExecStartPre=-/home/admin/config.scripts/blitz.web.api.sh update-config
ExecStart=sudo -u admin /usr/bin/python -m uvicorn app.main:app --port 11111 --host=0.0.0.0 --root-path /api
User=root
Group=root
Type=simple
Restart=always
StandardOutput=journal
StandardError=journal

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/blitzapi.service

  sudo systemctl enable blitzapi
  sudo systemctl start blitzapi

  # TODO: remove after experimental step
  sudo ufw allow 11111 comment 'WebAPI Develop'

  # install info
  echo "# the API doc should now be available under http://[LOCALHOST]/api/docs or try port 11111 for testing"
  echo "# check for systemd:  sudo systemctl status blitzapi"
  echo "# check for logs:     sudo journalctl -f -u blitzapi"

  exit 0
fi

###################
# UPDATE CONFIG
###################
if [ "$1" = "update-config" ]; then

  cd /home/admin/blitz_api
  cp ./.env_sample ./.env
  dateStr=$(date)
  echo "# Update Web API CONFIG (${dateStr})"

  # set platform to raspiblitz
  sed -i "s/^# platform=.*/platform=raspiblitz/g" ./.env
  
  # make secret consistent over restarts/reboots/updates so that browser sessions stay alive 
  SECRET=$(sudo shasum -a 256 /etc/ssh/ssh_host_rsa_key.pub | cut -d " " -f1)
  sed -i "s/^secret=.*/secret=${SECRET}/g" ./.env

  # keep in mind this needs also to work later for setup when no HDD/SSD or bitcoin is configured yet
  configAvailable=$(sudo ls /mnt/hdd/raspiblitz.conf 2>/dev/null | grep -c "raspiblitz.conf")
  echo "# configAvailable(${configAvailable})"
  if [ ${configAvailable} -lt 1 ]; then

    echo "# running in setup mode - minimal default config"
    sed -i "s/^login_password=.*/login_password='raspiblitz'/g" ./.env
    network=""
    lightning=""

  else

    echo "# running in config mode - run full setup"
    source /mnt/hdd/raspiblitz.conf

    # todo: login pass should later be password - run as a login test against the system
    # but for now user passwordB - the RPC password 
    LOGINPASS=$(sudo cat /mnt/hdd/${network}/${network}.conf | grep rpcpassword | cut -c 13-)
    sed -i "s/^login_password=.*/login_password='${LOGINPASS}'/g" ./.env

  fi

  if [ "${network}" == "bitcoin" ]; then
  
    echo "# CONFIG Web API Bitcoin --> ON"
    RPCUSER=$(sudo cat /mnt/hdd/${network}/${network}.conf | grep rpcuser | cut -c 9-)
    RPCPASS=$(sudo cat /mnt/hdd/${network}/${network}.conf | grep rpcpassword | cut -c 13-)
    sed -i "s/^network=.*/network=${chain}net/g" ./.env
    sed -i "s/^bitcoind_ip_mainnet=.*/bitcoind_ip_mainnet=127.0.0.1/g" ./.env
    sed -i "s/^bitcoind_ip_testnet=.*/bitcoind_ip_testnet=127.0.0.1/g" ./.env
    sed -i "s/^bitcoind_user=.*/bitcoind_user=${RPCUSER}/g" ./.env
    sed -i "s/^bitcoind_pw=.*/bitcoind_pw=${RPCPASS}/g" ./.env

  else
    echo "# CONFIG Web API Bitcoin --> OFF"
    sed -i "s/^network=.*/network=/g" ./.env
  fi
  
  
  # configure LND (not set on setup mode)
  if [ "${lightning}" == "lnd" ]; then

    echo "# CONFIG Web API Lightning --> LND"
    tlsCert=$(sudo xxd -ps -u -c 1000 /mnt/hdd/lnd/tls.cert)
    adminMacaroon=$(sudo xxd -ps -u -c 1000 /mnt/hdd/lnd/data/chain/bitcoin/${chain}net/admin.macaroon)
    sed -i "s/^ln_node=.*/ln_node=lnd/g" ./.env
    sed -i "s/^lnd_macaroon=.*/lnd_macaroon=${adminMacaroon}/g" ./.env
    sed -i "s/^lnd_cert=.*/lnd_cert=${tlsCert}/g" ./.env
    if [ "${chain}" == "main" ];then
      L2rpcportmod=0
      portprefix=""
    elif [ "${chain}" == "test" ];then
      L2rpcportmod=1
      portprefix=1
    elif [ "${chain}" == "sig" ];then
      L2rpcportmod=3
      portprefix=3
    fi
    lnd_grpc_port=1${L2rpcportmod}009
    lnd_rest_port=${portprefix}8080
    sed -i "s/^lnd_grpc_ip=.*/lnd_grpc_ip=127.0.0.1/g" ./.env
    sed -i "s/^lnd_grpc_port=.*/lnd_grpc_port=${lnd_grpc_port}/g" ./.env
    sed -i "s/^lnd_rest_port=.*/lnd_rest_port=${lnd_rest_port}/g" ./.env

  # configure CL (not set on setup mode)
  elif [ "${lightning}" == "cl" ]; then
    
    echo "# CONFIG Web API Lightning --> CL"
    sed -i "s/^ln_node=.*/ln_node=cl/g" ./.env
    
    # TODO: ADD C-Lightning config as soon as available
    echo "# MISSING CL CONFIG YET"

  else
    echo "# CONFIG Web API Lightning --> OFF"
    sed -i "s/^ln_node=.*/ln_node=/g" ./.env
  fi

  echo "# '.env' config updates - blitzapi maybe needs to be restarted"
  exit 0

fi

###################
# UPDATE CODE
###################
if [ "$1" = "update-code" ]; then

  echo "# Update Web API CODE"
  sudo systemctl stop blitzapi
  cd /home/admin/blitz_api
  git fetch
  git pull
  pip install -r requirements.txt
  sudo systemctl start blitzapi
  echo "# blitzapi updates and restarted"
  exit 0

fi

###################
# OFF / UNINSTALL
###################
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  echo "# UNINSTALL Web API"
  echo "# - stop/disable/delete service"
  sudo systemctl stop blitzapi
  sudo systemctl disable blitzapi
  sudo rm /etc/systemd/system/blitzapi.service
  echo "# - delete folder /home/admin/blitz_api"
  sudo rm -r /home/admin/blitz_api
  exit 0

fi
