#!/bin/bash

# deprecated - see: https://github.com/rootzoll/raspiblitz/issues/2290
# only use for development reasons

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "small config script to change between testnet and mainnet"
 echo "network.chain.sh [testnet|mainnet]"
 exit 1
fi

# check input
if [ "$1" != "testnet" ] && [ "$1" != "mainnet" ]; then
 echo "FAIL - unknown value: $1"
 exit 1
fi

# stop services
echo "making sure services are not running"
sudo systemctl stop lnd 2>/dev/null
sudo systemctl stop bitcoind 2>/dev/null

# editing network config files (hdd & admin user)
echo "edit bitcoin config .."
# fix old lnd config file (that worked with switching comment)
sudo sed -i "s/^#testnet=.*/testnet=1/g" /mnt/hdd/bitcoin/bitcoin.conf
sudo sed -i "s/^#testnet=.*/testnet=1/g" /home/admin/.bitcoin/bitcoin.conf
# changes based on parameter
if [ "$1" = "testnet" ]; then
  echo "editing /mnt/hdd/bitcoin/bitcoin.conf"
  sudo sed -i "s/^testnet=.*/testnet=1/g" /mnt/hdd/bitcoin/bitcoin.conf
  echo "editing /home/admin/.bitcoin/bitcoin.conf"
  sudo sed -i "s/^testnet=.*/testnet=1/g" /home/admin/.bitcoin/bitcoin.conf
  # switch rpc ports
  sudo sed -i "s/^main.rpcport=.*/main.rpcport=18332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^test.rpcport=.*/test.rpcport=8332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^main.rpcbind=.*/main.rpcbind=127.0.0.1:18332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^test.rpcbind=.*/test.rpcbind=127.0.0.1:8332/g" /home/admin/.bitcoin/bitcoin.conf
else
  echo "editing /mnt/hdd/bitcoin/bitcoin.conf"
  sudo sed -i "s/^testnet=.*/testnet=0/g" /mnt/hdd/bitcoin/bitcoin.conf
  echo "editing /home/admin/.bitcoin/bitcoin.conf"
  sudo sed -i "s/^testnet=.*/testnet=0/g" /home/admin/.bitcoin/bitcoin.conf
  # switch rpc ports
  sudo sed -i "s/^main.rpcport=.*/main.rpcport=8332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^test.rpcport=.*/test.rpcport=18332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^main.rpcbind=.*/main.rpcbind=127.0.0.1:8332/g" /home/admin/.bitcoin/bitcoin.conf
  sudo sed -i "s/^test.rpcbind=.*/test.rpcbind=127.0.0.1:18332/g" /home/admin/.bitcoin/bitcoin.conf
fi

# editing lnd config files (hdd & admin user)
echo "edit lightning config .."
# fix old lnd config file (that worked with switching comment)
sudo sed -i "s/^#bitcoin.testnet=.*/bitcoin.testnet=1/g" /mnt/hdd/lnd/lnd.conf
# changes based on parameter
if [ "$1" = "testnet" ]; then
  echo "editing /mnt/hdd/lnd/lnd.conf"
  sudo sed -i "s/^bitcoin.mainnet.*/bitcoin.mainnet=0/g" /mnt/hdd/lnd/lnd.conf
  sudo sed -i "s/^bitcoin.testnet.*/bitcoin.testnet=1/g" /mnt/hdd/lnd/lnd.conf
  # deactivate prestart
  sudo sed -i "s/^ExecStartPre=.*/ExecStartPre=-\/home\/admin\/config.scripts\/lnd.check.sh/g" /etc/systemd/system/lnd.service
else
  echo "editing /mnt/hdd/lnd/lnd.conf"
  sudo sed -i "s/^bitcoin.mainnet.*/bitcoin.mainnet=1/g" /mnt/hdd/lnd/lnd.conf
  sudo sed -i "s/^bitcoin.testnet.*/bitcoin.testnet=0/g" /mnt/hdd/lnd/lnd.conf
  # deactivate prestart
  sudo sed -i "s/^ExecStartPre=.*/ExecStartPre=-\/home\/admin\/config.scripts\/lnd.check.sh/g" /etc/systemd/system/lnd.service
fi

# editing the raspi blitz config file
echo "editing /mnt/hdd/raspiblitz.conf"
if [ "$1" = "testnet" ]; then
  /home/admin/config.scripts/blitz.conf.sh set chain "test"
else
  /home/admin/config.scripts/blitz.conf.sh set chain "main"
fi

# now a reboot is needed to load all services fresh
# starting up process will display chain sync
# ask user todo reboot
echo "OK - all configs changed to: $1"
echo "needs reboot to activate new setting"
