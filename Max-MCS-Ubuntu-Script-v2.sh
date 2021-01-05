#!/bin/bash
clear
echo "MCS Ubuntu Script v2.1 Updated 1/4/2021 at 8:00pm EST"
echo "Created by Massimo Marino"

if [[ "$(whoami)" != root ]]
then
	echo "This script can only be run as root"
	exit 1
fi

failsafe=~/Desktop/changelog.log
if [[ -f "$failsafe" ]]
then
	rm ~/Desktop/changelog.log
	rm -r ~/Desktop/backups
	exit 1
fi

clear 
echo "Creating backup folder and backing up important files"
mkdir -p ~/Desktop/backups
chmod 777 ~/Desktop/backups
cp /etc/group ~/Desktop/backups/
cp /etc/passwd ~/Desktop/backups/
cp /etc/sysctl.conf ~/Desktop/backups/ 
touch changelog.txt ~/Desktop
chmod 777 ~/Desktop/changelog.log
echo "List of changes made by script:" > ~/Desktop/changelog.log
echo "- Backups folder created\n- Important files backed up" >> ~/Desktop/changelog.log

clear
echo "Updating apt"
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get dist-upgrade -y -qq
echo "- Package installer 'apt' updated (update, upgrade, dist-upgrade)" >> ~/Desktop/changelog.log

clear
echo "Installing useful packages"
apt-get install firefox -y -qq
apt-get install apparmor -y -qq
apt-get install apparmor-profiles -y -qq
apt-get install rkhunter -y -qq
apt-get install chkrootkit -y -qq
apt-get install iptables -y -qq
apt-get install portsentry -y -qq
apt-get install lynis -y -qq
apt-get install ufw -y -qq
apt-get install gufw -y -qq
apt-get install clamav -y -qq
apt-get install clamtk -y -qq
apt-get install libpam-cracklib -y -qq
apt-get install auditd -y -qq
apt-get install tree -y -qq
apt-get install --reinstall coreutils -y -qq
echo "- Packages firefox, apparmor, rkhunter, chkrootkit, iptables, portsentry, lynis, ufw, gufw, libpam-cracklib, auditd, tree, clamav, and clamtk installed; coreutils reinstalled" >> ~/Desktop/changelog.log

clear
echo "Enabling auditing"
auditctl -e 1
echo "- Auditing enabled with auditd (can be configured in /etc/audit/auditd.conf" >> ~/Desktop/changelog.log

clear
echo "Configuring firewall (UFW)"
ufw enable
ufw deny 1337
ufw deny 23
ufw deny 2049
ufw deny 515
ufw deny 111
ufw logging on
ufw logging high
echo "- Firewall configured (Firewall enabled, Ports 1337, 23, 2049, 515, and 111 denied, Logging on and high)\n" >> ~/Desktop/changelog.log

clear
echo "Service Auditing"
echo "Is openssh-server a critical service on this machine?"
read sshYN
if [[ $sshYN == "yes" ]]; then
	apt-get install ssh -y -qq
	apt-get install openssh-server -y -qq
	apt-get upgrade openssl libssl-dev -y -qq
	apt-cache policy openssl libssl-dev
	echo "- Packages ssh and openssh-server installed and heartbleed bug fixed" >> ~/Desktop/changelog.log
else
	echo "- openssh-server and ssh were not installed on this machine" >> ~/Desktop/changelog.log
fi

clear
echo "Is NGINX a critical service on this machine?"
read nginxYN
if [[ $nginxYN == "yes" ]]; then
	apt-get install nginx
	echo "- NGINX installed" >> ~/Desktop/changelog.log
elif [[ $nginxYN == "no" ]]; then
	apt-get purge nginx -y -qq
	apt-get purge nginx-common -y -qq
	echo "- NGINX removed from the machine" >> ~/Desktop/changelog.log
fi

clear
echo "Is Samba a critical service on this machine?"
read sambaYN
if [[ $sambaYN == "yes" ]]; then
	ufw allow netbios-ns
	ufw allow netbios-dgm
	ufw allow netbios-ssn
	ufw allow microsoft-ds
	apt-get install samba -y -qq
	apt-get install system-config-samba -y -qq
	echo "- Samba installed and allowed" >> ~/Desktop/changelog.log
elif [[ $sambaYN == "no" ]]; then
	ufw deny netbios-ns
	ufw deny netbios-dgm
	ufw deny netbios-ssn
	ufw deny microsoft-ds
	apt-get purge samba -y -qq
	apt-get purge samba-common -y  -qq
	apt-get purge samba-common-bin -y -qq
	apt-get purge samba4 -y -qq
	echo "- Samba uninstalled and blocked" >> ~/Desktop/changelog.log
fi

clear
echo "Is FTP a critical service on this machine?"
read ftpYN
if [[ $ftpYN == "yes" ]]; then
	ufw allow ftp 
	ufw allow sftp 
	ufw allow saft 
	ufw allow ftps-data 
	ufw allow ftps
	service vsftpd restart
	echo "- FTP installed and allowed" >> ~/Desktop/changelog.log
elif [[ $ftpYN == "no" ]]; then
	ufw deny ftp 
	ufw deny sftp 
	ufw deny saft 
	ufw deny ftps-data 
	ufw deny ftps
	apt-get purge vsftpd -y -qq
	echo "- FTP uninstalled and blocked" >> ~/Desktop/changelog.log
fi

clear
echo "Is Telnet a critical service on this machine?"
read telnetYN
if [[ $telnetYN == "yes" ]]; then
	ufw allow telnet 
	ufw allow rtelnet 
	ufw allow telnets
	echo "- Telnet allowed" >> ~/Desktop/changelog.log
elif [[ $telnetYN == "no" ]]; then
	ufw deny telnet 
	ufw deny rtelnet 
	ufw deny telnets
	apt-get purge telnet -y -qq
	apt-get purge telnetd -y -qq
	apt-get purge inetutils-telnetd -y -qq
	apt-get purge telnetd-ssl -y -qq
	apt-get purge vsftpd -y -qq
	echo "- Telnet uninstalled and blocked" >> ~/Desktop/changelog.log
fi

clear
echo "Is MySQL a critical service on this machine?"
read sqlYN
if [[ $sqlYN == "yes" ]]; then
	ufw allow ms-sql-s 
	ufw allow ms-sql-m 
	ufw allow mysql 
	ufw allow mysql-proxy
	echo "- MySQL allowed (WIP)" >> ~/Desktop/changelog.log
elif [[ $sqlYN == "no" ]]; then
	ufw deny ms-sql-s 
	ufw deny ms-sql-m 
	ufw deny mysql 
	ufw deny mysql-proxy
	apt-get purge mysql -y -qq
	echo "- MySQL uninstalled and blocked (WIP)" >> ~/Desktop/changelog.log
fi

clear
echo "Is this machine a web server?"
read webYN
if [[ $webYN == "yes" ]]; then
	apt-get install apache2 -y -qq
	ufw allow http 
	ufw allow https
	echo "- Apache2 installed and http(s) allowed\n" >> ~/Desktop/changelog.log
elif [[ $webYN == "no" ]]; then
	ufw deny http
	ufw deny https
	apt-get purge apache2 -y -qq
	#rm -r /var/www/*
	echo "- Apache2 removed and http(s) blocked\n" >> ~/Desktop/changelog.log
fi

clear 
echo "Should root user be locked?"
read lockRootYN
if [[ $lockRootYN == yes ]]
then 
	usermod -L root
	echo "- Root account locked. Use 'usermod -U root' to unlock it"
fi

clear
echo "Removing netcat"
apt-get purge netcat -y -qq
apt-get purge netcat-openbsd -y -qq
apt-get purge netcat-traditional -y -qq
apt-get purge ncat -y -qq
apt-get purge pnetcat -y -qq
apt-get purge socat -y -qq
apt-get purge sock -y -qq
apt-get purge socket -y -qq
apt-get purge sbd -y -qq
rm /usr/bin/nc

clear
echo "Removing John the Ripper"
apt-get purge john -y -qq
apt-get purge john-data -y -qq

clear
echo "Removing Hydra"
apt-get purge hydra -y -qq
apt-get purge hydra-gtk -y -qq

clear
echo "Removing Aircrack-NG"
apt-get purge aircrack-ng -y -qq

clear
echo "Removing FCrackZIP"
apt-get purge fcrackzip -y -qq

clear
echo "Removing LCrack"
apt-get purge lcrack -y -qq

clear
echo "Removing OphCrack"
apt-get purge ophcrack -y -qq
apt-get purge ophcrack-cli -y -qq

clear
echo "Removing Pyrit"
apt-get purge pyrit -y -qq

clear
echo "Removing RARCrack"
apt-get purge rarcrack -y -qq

clear
echo "Removing SipCrack"
apt-get purge sipcrack -y -qq

clear
echo "Removing LogKeys"
apt-get purge logkeys -y -qq

clear
echo "Removing Zeitgeist"
apt-get purge zeitgeist-core -y -qq
apt-get purge zeitgeist-datahub -y -qq
apt-get purge python-zeitgeist -y -qq
apt-get purge rhythmbox-plugin-zeitgeist -y -qq
apt-get purge zeitgeist -y -qq

clear
echo "Removing NFS"
apt-get purge nfs-kernel-server -y -qq
apt-get purge nfs-common -y -qq
apt-get purge portmap -y -qq
apt-get purge rpcbind -y -qq
apt-get purge autofs -y -qq

clear
echo "Removing VNC"
apt-get purge vnc4server -y -qq
apt-get purge vncsnapshot -y -qq
apt-get purge vtgrab -y -qq

clear
echo "Removing Wireshark"
apt-get purge wireshark

clear
echo "Cleaning up Packages"
apt-get autoremove -y -qq
apt-get autoclean -y -qq
apt-get clean -y -qq
echo "- Removed netcat, John the Ripper, Hydra, Aircrack-NG, FCrackZIP, LCrack, OphCrack, Pyrit, rarcrack, SipCrack, LogKeys, Zeitgeist, NFS, VNC, and cleaned up packages" >> ~/Desktop/changelog.log

clear
echo "Denying outside packets"
iptables -A INPUT -p all -s localhost  -i eth0 -j DROP
echo "- Denied outside packets" >> ~/Desktop/changelog.log

clear
echo "Disabling reboot with Ctrl-Alt-Delete"
sudo systemctl mask ctrl-alt-del.target
sudo systemctl daemon-reload
echo "- Disabled reboot with Ctrl-Alt-Delete" >> ~/Desktop/changelog.log

clear
echo "Disallowing guest account"
cp /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf ~/Desktop/backups/
sed -i '2s/.*/allow-guest=false/' >> /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf
echo "- Disabled guest account" >> ~/Desktop/changelog.log

clear
echo "Securing /etc/rc.local"
echo > /etc/rc.local
echo "exit 0" > /etc/rc.local
echo "- /etc/rc.local secured" >> ~/Desktop/changelog.log

clear
echo "Editing /etc/login.defs"
cp /etc/login.defs ~/Desktop/backups/
sed -i '160s/.*/PASS_MAX_DAYS\o01130/' /etc/login.defs
sed -i '161s/.*/PASS_MIN_DAYS\o0117/' /etc/login.defs
sed -i '162s/.*/PASS_WARN_AGE\o01114/' /etc/login.defs
echo "- /etc/login.defs configured (Min days 7, Max days 30, Warn age 14)"

clear
echo "Editing /etc/ssh/ssh/sshd_config"
cp /etc/ssh/ssh_config ~/Desktop/backups/
sed -i '32s/.*/PermitRootLogin no/' /etc/ssh/sshd_config
service ssh restart
echo "- PermitRootLogin set to no in /etc/ssh/sshd_config" >> ~/Desktop/changelog.log

clear
echo "Editing /etc/pam.d/common-password"
cp /etc/pam.d/common-password ~/Desktop/backups/
sed -i '26s/.*/password\o011[success=1 default=ignore]\o011pam_unix.so obscure pam_unix.so obscure use_authtok try_first_pass remember=5 minlen=8/' /etc/pam.d/common-password
sed -i '25s/.*/password\o011requisite\o011\o011\o011pam_cracklib.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password
echo "- /etc/pam.d/common-password edited (remember=5, minlen=8, complexity requirements)" >> ~/Desktop/changelog.log

clear
echo "Setting account lockout policy"
cp /etc/pam.d/common-auth ~/Desktop/backups/
sed -i '16s/.*/# here are the per-package modules (the "Primary" block)\n/' /etc/pam.d/common-auth
sed -i '17s/.*/auth\o011required\o011\o011\o011pam_tally2.so onerr=fail deny=5 unlock_time=1800 audit/' /etc/pam.d/common-auth
echo "- Account lockout policy set in /etc/pam.d/common-auth" >> ~/Desktop/changelog.log

clear
echo "Manual changes:"
echo "- Run ClamTK antivirus scan"
echo "- Run rkhunter scan (sudo rkhunter --check)"
echo "- Check for backdoors (netstat -tulpn)"
echo "- Run bash vulnerability test"
echo "- Check for malicious packages that might still be installed (dpkg -l | grep <keyword> (i.e. crack))"
echo "- Make sure updates are checked for daily and update Ubuntu according to the ReadMe"
echo "- Edit sysctl.conf (BE CAREFUL! Don't cut internet)"
echo "- Make sure root is the only root account (:0:) (in /etc/group)"
echo "- Find media files (might add to script later)"
echo "- Audit users"
echo "Script done! Good luck :D"