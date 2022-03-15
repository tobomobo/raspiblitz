Running RaspiBlitz in a VM on MacOS (M1 Chip)

- Install UTM for MacOS (QEMU UI): https://mac.getutm.app/

Creating a UTM VM of RaspiBlitz from scratch:

- Download Server install image ubuntu-20.04-live-server-amd64.iso: https://releases.ubuntu.com/20.04/
- Create new VM with "Emulate", Linux & choose downloaded iso file
- Chosse Hardware: x86_64, StandardPC 2009, 4GB RAM, 4 Cores, 32GB storage
- Dont choose a shared directory yet
- Name "RaspiBlitzVM"
- Start VM go thru install process
- Choose your lang / keyboard
- Wait for Network info - write down local ip (192.168.64.6) 
- Go with further defaults & let format drive 
- On Profile: raspiblitz / raspiblitz / pi / 12345678 / 12345678
- Activate OpenSSH install - no other installs
- Restart & Eject CD-Rom (the iso image)

- ssh in as user pi with password 12345678
- run build script: wget --no-cache https://raw.githubusercontent.com/rootzoll/raspiblitz/dev/build_sdcard.sh && sudo bash build_sdcard.sh -b dev -d hdmi
- run: sudo apt-get install davfs2 spice-vdagent spice-webdavd
- run: release

- In UTM Settings on VM when stopped add "New Drive" 1TB IDE (create)
- boot up VM again
- SSH in and run Setup process

Further notes:

Unsolved how to run with testnet - a full mainnet blockchain is too big & slow and is difficult to

Mount WebDAV share using command-line
https://sleeplessbeastie.eu/2017/09/04/how-to-mount-webdav-share/


