#!/bin/bash

echo "MCS Ubuntu Script v2.0.0 Updated 10/23/2021 at 5:11 PM EST"

if [[ "$(whoami)" != root ]]; then
	echo "This script can only be run as root"
	exit 1
fi

declare -a services
islamp="no"
DIALOG_OK=0
DIALOG_ESC=255

init() {
	\unalias -a
    apt-get install dialog -y 
	exec 3>&1
	username=$(dialog \
		--title "INPUT BOX" \
		--clear  \
		--nocancel \
		--inputbox \
		"Please enter the username of the main user on this machine:" \
		16 51 2>&1 1>&3)
	return_value=$?
	exec 3>&-

	case $return_value in
		"$DIALOG_OK")
			clear
			logsDir="/home/$username/Desktop/logs"
			homeDir="/home/$username"
			mkdir -p "${logsDir}"
			mkdir -p "${logsDir}/backups"
			cp /etc/group "${logsDir}/backups/"
			cp /etc/passwd "${logsDir}/backups/"
			cp /etc/shadow "${logsDir}/backups/"
			touch "${logsDir}/changelog.log"
			chmod -R 777 "${logsDir}"
			;;
		"$DIALOG_ESC")
			clear
            echo "Program aborted." >&2
            exit 1
            ;;
	esac
	tmp_file=$(mktemp 2>/dev/null) || tmp_file=/tmp/test$$
    trap 'rm -f $tmp_file' 0 1 2 SIGTRAP 15

	dialog --backtitle "Distribution Choice" \
            --title "Which distribution is this image?" --clear --nocancel \
            --radiolist "Choose the distribution as stated in the README by pressing SPACE:" 20 61 5 \
                "ubu-18"  "Ubuntu 18.04" on \
                "ubu-20"    "Ubuntu 20.04" off \
                "deb-10" "Debian 10" off 2> $tmp_file
    return_value=$?

    choice=$(cat $tmp_file)
    case $return_value in
    0)
		clear
        dist_folder=$choice
		;;
    255)
        clear
        echo "Program aborted."
        exit 1
        ;;
    esac
}

packages() {
	cp "/home/$username/Desktop/linux/$dist_folder/sources.list" /etc/apt/sources.list
	apt-get update -y
	apt-get install ufw -y -qq
	apt-get install libpam-tmpdir -y -qq
	apt-get install libpam-pkcs11 -y -qq
	apt-get install libpam-pwquality -y -qq
	apt-get install python3-pip -y -qq
	pip3 install bs4
	apt-get install unattended-upgrades -y -qq
	dpkg-reconfigure --priority=low unattended-upgrades
	cp "/home/$username/Desktop/linux/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
	cp "/home/$username/Desktop/linux/50unattended-upgrades" /etc/apt/apt.conf.d/50unattended-upgrades
	apt-get update -y
	apt-get upgrade -y
}

firewall() {
	ufw deny 1337 # trojan port
	ufw deny 23 # telnet
	ufw deny 515 # spooler
	ufw deny 111 # sun remote thing
	ufw deny 135 # ms rpc
	ufw deny 137, 138, 139 # netbios
	ufw deny 69 # tftp
	ufw default deny incoming
	ufw default deny routed
	ufw logging on
	ufw logging high
	ufw enable
}

services() {

	if [[ ${services[*]} =~ 'apache' && ${services[*]} =~ 'mysql' ]]; then
		apt-get purge nginx -y -qq
		apt-get purge nginx-common -y -qq
		apt-get purge nginx-core -y -qq
		echo "- NGINX removed from the machine" >>"${homeDir}/Desktop/logs/changelog.log"
		apt-get install apache2 -y -qq
		apt-get install apache2-utils -y -qq
		apt-get install libapache2-mod-evasive -y -qq
		apt-get install libapache2-mod-security2 -y -qq
		ufw allow in "Apache Full"
		ufw allow http
		ufw allow https
		systemctl restart apache2
		service apache2 restart

		echo "####Configuring Apache2 config file####"
		cp /etc/apache2/apache2.conf "${homeDir}/Desktop/logs/backups"
		cp "${homeDir}/Desktop/linux/apache2.conf" /etc/apache2/apache2.conf
		chmod 511 /usr/sbin/apache2
		chmod -R 755 /var/log/apache2/
		chmod -R 755 /var/www
		/etc/init.d/apache2 restart

		echo "####Installing PHP####"
		apt-get install php -y -qq
		apt-get install libapache2-mod-php -y -qq
		apt-get install php-mysql -y -qq
		cp /etc/apache2/mods-enabled/dir.conf "${homeDir}/Desktop/logs/backups"
		rm /etc/apache2/mods-enabled/dir.conf
		cp "${homeDir}/Desktop/linux/dir.conf" /etc/apache2/mods-enabled
		systemctl restart apache2
		echo "###Configuring php.ini####"
		cp /etc/php/7.2/apache2/php.ini "${homeDir}/Desktop/logs/backups/"
		cp "${homeDir}/Desktop/linux/php.ini" /etc/php/7.2/apache2/php.ini
		service apache2 restart

		#install + config mysql
		ufw allow ms-sql-s
		ufw allow ms-sql-m
		ufw allow mysql
		ufw allow mysql-proxy
		apt-get install mysql-server -y -qq
		chown -R mysql:mysql /var/lib/mysql
		dpkg --configure -a
		ln -s /etc/mysql/mysql.conf.d /etc/mysql/conf.d
		mysqld --initialize --explicit_defaults_for_timestamp
		mysql_secure_installation

		islamp='yes'
	fi

	if [[ ${services[*]} =~ 'ssh' ]]; then
		apt-get install ssh -y -qq
		apt-get install openssh-server -y -qq
		apt-get upgrade openssl libssl-dev -y -qq
		apt-cache policy openssl libssl-dev
		echo "- Packages ssh and openssh-server installed and heartbleed bug fixed" >>"${homeDir}/Desktop/logs/changelog.log"

		echo "####Editing /etc/sshd/sshd_config####"
		cp /etc/ssh/sshd_config "${homeDir}/Desktop/logs/backups/"
		cp "${homeDir}/Desktop/linux/sshd_config" /etc/ssh/sshd_config
		chown root:root /etc/ssh/sshd_config
		chmod og-rwx /etc/ssh/sshd_config
		find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chown root:root {} \;
		find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \;
		find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chmod 0644 {} \;
		find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chown root:root {} \;
		echo "- Configured /etc/ssh/sshd_config" >>"${homeDir}/Desktop/logs/changelog.log"

		echo "####Securing SSH keys####"
		mkdir -p "${homeDir}/.ssh/"
		chmod 700 "${homeDir}/.ssh"
		chmod 600 "${homeDir}/.ssh/authorized_keys"
		chmod 600 "${homeDir}/.ssh/id_rsa"
		echo "- Secured SSH keys" >>"${homeDir}/Desktop/logs/changelog.log"

		echo "####SSH port can accept SSH connections####"
		ufw allow 22

		service ssh restart
		echo "- SSH configured" >>"${homeDir}/Desktop/logs/changelog.log"
	else
		apt-get purge openssh-server
		ufw deny ssh
	fi

	if [[ ${services[*]} =~ 'smb' || ${services[*]} =~ 'samba' ]]; then
		ufw allow microsoft-ds
		ufw allow 137/udp
		ufw allow 138/udp
		ufw allow 139/tcp
		ufw allow 445/tcp
		apt-get install samba -y -qq
		apt-get install system-config-samba -y -qq
		apt-get install libpam-winbind -y -qq
		systemctl restart smbd.service nmbd.service
		echo "- Samba installed and allowed" >>"${homeDir}/Desktop/logs/changelog.log"
	else
		ufw deny netbios-ns
		ufw deny netbios-dgm
		ufw deny netbios-ssn
		ufw deny microsoft-ds
		apt-get purge samba -y -qq
		echo "- Samba uninstalled and blocked" >>"${homeDir}/Desktop/logs/changelog.log"
	fi

	if [[ ${services[*]} =~ 'vsftpd' ]]; then
		apt-get install vsftpd
		cp /etc/vsftpd.conf /etc/vsftpd.conf_default
		cp /etc/vsftpd.conf "${homeDir}/Desktop/logs/backups/"
		service vsftpd start
		service vsftpd enable
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem
		cp "${homeDir}/Desktop/linux/vsftpd.conf" /etc/vsftpd.conf
		mkdir /srv/ftp/new_location
		usermod –d /srv/ftp/new_location ftp
		systemctl restart vsftpd.service
		ufw allow 20/tcp
		ufw allow 21/tcp
		ufw allow 40000:50000/tcp
		ufw allow 990/tcp
		ufw allow ftp
		ufw allow sftp
		ufw allow saft
		ufw allow ftps-data
		ufw allow ftps
		service vsftpd restart
		echo "- FTP installed and allowed" >>"${homeDir}/Desktop/logs/changelog.log"
	else
		service vsftpd stop
		ufw deny ftp
		ufw deny sftp
		ufw deny saft
		ufw deny ftps-data
		ufw deny ftps
		apt-get purge vsftpd -y -qq
		echo "- FTP uninstalled and blocked" >>"${homeDir}/Desktop/logs/changelog.log"
	fi

	service telnet stop
	ufw deny telnet
	ufw deny rtelnet
	ufw deny telnets
	apt-get purge telnet -y -qq
	apt-get purge telnetd -y -qq
	apt-get purge inetutils-telnetd -y -qq
	apt-get purge telnetd-ssl -y -qq

	if [[ ${services[*]} =~ 'apache' && $islamp == 'no' || ${services[*]} =~ 'nginx' && $islamp == 'no' ]]; then
		if [[ ${services[*]} =~ 'nginx' ]]; then
			apt-get purge apache2 -y -qq
			apt-get purge apache2-bin -y -qq
			apt-get purge apache2-utils -y -qq
			apt-get purge libapache2-mod-evasive -y -qq
			apt-get purge libapache2-mod-security2 -y -qq
			echo "- Apache2 removed" >>"${homeDir}/Desktop/logs/changelog.log"
			apt-get install nginx -y -qq
			ufw allow http
			ufw allow https
			echo "- NGINX installed" >>"${homeDir}/Desktop/logs/changelog.log"
		elif [[ ${services[*]} =~ 'apache' ]]; then
			apt-get purge nginx -y -qq
			apt-get purge nginx-common -y -qq
			apt-get purge nginx-core -y -qq
			echo "- NGINX removed from the machine" >>"${homeDir}/Desktop/logs/changelog.log"
			apt-get install apache2 -y -qq
			apt-get install apache2-utils -y -qq
			apt-get install libapache2-mod-evasive -y -qq
			apt-get install libapache2-mod-security2 -y -qq
			ufw allow http
			ufw allow https
			systemctl restart apache2
			echo "####Configuring ufw for web servers####"
			chmod 511 /usr/sbin/apache2
			chmod -R 750 /var/log/apache2/
			chmod -R 444 /var/www
			/etc/init.d/apache2 restart
			echo "- Apache2 installed, configured, and http(s) allowed" >>"${homeDir}/Desktop/logs/changelog.log"
		fi
	elif [[ $islamp == 'no' ]]; then
		apt-get purge nginx -y -qq
		apt-get purge nginx-common -y -qq
		apt-get purge nginx-core -y -qq
		echo "- NGINX removed from the machine" >>"${homeDir}/Desktop/logs/changelog.log"
		ufw deny http
		ufw deny https
		apt-get purge apache2 -y -qq
		apt-get purge apache2-bin -y -qq
		apt-get purge apache2-utils -y -qq
		apt-get purge libapache2-mod-evasive -y -qq
		apt-get purge libapache2-mod-security2 -y -qq
		rm -r /var/www/*
		echo "- Apache2 removed and http(s) blocked" >>"${homeDir}/Desktop/logs/changelog.log"
	fi

	ufw deny smtp
	ufw deny pop3
	ufw deny imap2
	ufw deny imaps
	ufw deny pop3s
	apt-get purge dovecot-* -y -qq

	if [[ ${services[*]} =~ 'bind9' || ${services[*]} =~ 'dns' ]]; then
		apt-get install bind9 -y -qq
		named-checkzone test.com. /var/cache/bind/db.test
		{
			echo "zone \"test.com.\" {"
			echo "\o011type master;"
			echo "\o011file \"db.test\";"
			echo "};"
		} >>/etc/bind/named.conf.default-zones
		systemctl restart bind9
	else
		systemctl stop bind9
		apt-get purge bind9 -y -qq
	fi

	if [[ ${services[*]} =~ 'mysql' && $islamp == 'no' ]]; then
		ufw allow ms-sql-s
		ufw allow ms-sql-m
		ufw allow mysql
		ufw allow mysql-proxy
		apt-get install mysql-server -y -qq
		mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
		mv /etc/mysql/debian.cnf /etc/mysql/debian.cnf.bak
		chown -R mysql:mysql /var/lib/mysql
		dpkg --configure -a
		ln -s /etc/mysql/mysql.conf.d /etc/mysql/conf.d
		mysqld --initialize --explicit_defaults_for_timestamp
		mysql_secure_installation
		echo "#########Checking if MySQL config file exists#########"
		cnfCheck=/etc/mysql/my.cnf
		if [[ -f "$cnfCheck" ]]; then
			echo "MySQL config file exists"
		else
			touch /etc/mysql/my.cnf
			echo "MySQL config file created" >>"${homeDir}/Desktop/logs/changelog.log"
		fi
		echo "#########Configuring my.cnf#########"
		{
			echo "[mysqld]"
			echo "max_connections = 400"
			echo "key_buffer = 16M"
			echo "myisam_sort_buffer_size = 32M"
			echo "join_buffer_size = 1M"
			echo "read_buffer_size = 1M"
			echo "sort_buffer_size = 2M"
			echo "table_cache = 1024"
			echo "thread_cache_size = 286"
			echo "interactive_timeout = 25"
			echo "wait_timeout = 1000"
			echo "connect_timeout = 10"
			echo "max_allowed_packet = 16M"
			echo "max_connect_errors = 10"
			echo "query_cache_limit = 1M"
			echo "query_cache_size = 16M"
			echo "query_cache_type = 1"
			echo "tmp_table_size = 16M"
			echo "skip-innodb"
			echo "local-infile=0"
			echo "bind-address=127.0.0.1"
			echo "skip-show-database"

			echo "[mysqld_safe]"
			echo "open_files_limit = 8192"

			echo "[mysqldump]"
			echo "quick"
			echo "max_allowed_packet = 16M"

			echo "[myisamchk]"
			echo "key_buffer = 32M"
			echo "sort_buffer = 32M"
			echo "read_buffer = 16M"
			echo "write_buffer = 16M"
		} >>/etc/mysql/my.cnf
		chown -R root:root /etc/mysql/
		chmod 644 /etc/mysql/my.cnf
    elif [[ $islamp == 'no' ]]; then
		ufw deny ms-sql-s
		ufw deny ms-sql-m
		ufw deny mysql
		ufw deny mysql-proxy
		apt-get purge mysql-server -y -qq
		apt-get purge mysql-client -y -qq
	fi

	apt-get purge cups -y -qq

}

general_config() {
	passwd -l root

	useradd -D -f 35

	systemctl mask ctrl-alt-del.target
	systemctl daemon-reload

	mkdir -p /etc/dconf/db/local.d/
	cp "/home/$username/Desktop/linux/00-disabled-CAD" /etc/dconf/db/local.d/
	dconf update

	systemctl start systemd-timesyncd.service
	timedatectl set-ntp true

	echo "ALL: ALL" >>/etc/hosts.deny
	chown root:root /etc/hosts.allow
	chmod 644 /etc/hosts.allow
	chown root:root /etc/hosts.deny
	chmod 644 /etc/hosts.deny

	echo "#########Disabling Uncommon Network protocols and file system configurations#########"
	touch /etc/modprobe.d/dccp.conf
	chmod 644 /etc/modprobe.d/dccp.conf
	echo "install dccp /bin/true" >/etc/modprobe.d/dccp.conf
	touch /etc/modprobe.d/sctp.conf
	chmod 644 /etc/modprobe.d/sctp.conf
	echo "install sctp /bin/true" >/etc/modprobe.d/sctp.conf
	touch /etc/modprobe.d/rds.conf
	chmod 644 /etc/modprobe.d/rds.conf
	echo "install rds /bin/true" >/etc/modprobe.d/rds.conf
	touch /etc/modprobe.d/tipc.conf
	chmod 644 /etc/modprobe.d/tipc.conf
	echo "install tipc /bin/true" >/etc/modprobe.d/tipc.conf
	touch /etc/modprobe.d/cramfs.conf
	chmod 644 /etc/modprobe.d/cramfs.conf
	echo "install cramfs /bin/true" >/etc/modprobe.d/cramfs.conf
	rmmod cramfs
	touch /etc/modprobe.d/freevxfs.conf
	chmod 644 /etc/modprobe.d/freevxfs.conf
	echo "install freevxfs /bin/true" >/etc/modprobe.d/freevxfs.conf
	rmmod freevxfs
	touch /etc/modprobe.d/jffs2.conf
	chmod 644 /etc/modprobe.d/jffs2.conf
	echo "install jffs2 /bin/true" >/etc/modprobe.d/jffs2.conf
	rmmod jffs2
	touch /etc/modprobe.d/hfs.conf
	chmod 644 /etc/modprobe.d/hfs.conf
	echo "install hfs /bin/true" >/etc/modprobe.d/hfs.conf
	rmmod hfs
	touch /etc/modprobe.d/hfsplus.conf
	chmod 644 /etc/modprobe.d/hfsplus.conf
	echo "install hfsplus /bin/true" >/etc/modprobe.d/hfsplus.conf
	rmmod hfsplus
	touch /etc/modprobe.d/squashfs.conf
	chmod 644 /etc/modprobe.d/squashfs.conf
	echo "install squashfs /bin/true" >/etc/modprobe.d/squashfs.conf
	rmmod squashfs
	touch /etc/modprobe.d/udf.conf
	chmod 644 /etc/modprobe.d/udf.conf
	echo "install udf /bin/true" >/etc/modprobe.d/udf.conf
	rmmod udf
	touch /etc/modprobe.d/vfat.conf
	chmod 644 /etc/modprobe.d/vfat.conf
	echo "install vfat /bin/true" >/etc/modprobe.d/vfat.conf
	rmmod vfat
	touch /etc/modprobe.d/usb-storage.conf
	chmod 644 /etc/modprobe.d/usb-storage.conf
	echo "install usb-storage /bin/true" >/etc/modprobe.d/usb-storage.conf
	rmmod usb-storage

	systemctl disable kdump.service

	echo "ENABLED=\"0\"" >>/etc/default/irqbalance

	if [[ -f "/etc/lightdm/lightdm.conf" ]]; then
		echo "allow-guest=false" >>/etc/lightdm/lightdm.conf
	fi
	
	echo >/etc/rc.local
	echo "exit 0" >/etc/rc.local

	cp /etc/login.defs "${homeDir}/Desktop/logs/backups/"
	cp "${homeDir}/Desktop/linux/login.defs" /etc/login.defs

	cp /etc/pam.d/common-password "${homeDir}/Desktop/logs/backups/"
	cp "${homeDir}/Desktop/linux/common-password" /etc/pam.d/common-password

	cp /etc/pam.d/common-auth "${homeDir}/Desktop/logs/backups/"
	cp "${homeDir}/Desktop/linux/common-auth" /etc/pam.d/common-auth

	cp /etc/pam.d/common-account "${homeDir}/Desktop/logs/backups/"
	cp "${homeDir}/Desktop/linux/common-account" /etc/pam.d/common-account

	cp /etc/sysctl.conf "${homeDir}/Desktop/logs/backups/"
	cp "${homeDir}/Desktop/linux/sysctl.conf" /etc/sysctl.conf

	cp /etc/fstab "${homeDir}/Desktop/logs/backups/"
	echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >>/etc/fstab

	chown root:root /etc/securetty
	chmod 0600 /etc/securetty

	cp "${homeDir}/Desktop/linux/pam_pkcs11.conf" /etc/pam_pkcs11/pam_pkcs11.conf

	echo "Authorized users only. All activity may be monitored and reported." >/etc/issue
	echo "Authorized users only. All activity may be monitored and reported." >/etc/issue.net

	# cp "/home/$username/Desktop/linux/greeter.dconf-defaults" /etc/gdm3/greeter.dconf-defaults
	# dconf update
	# systemctl restart gdm3

	sed -i '45s/.*/*\o011\o011 hard\o011 core\o011\o011 0/' /etc/security/limits.conf
	sed -i '1s/^/* hard maxlogins 10\n/' /etc/security/limits.conf

	find /lib /lib64 /usr/lib -perm /022 -type d -exec chmod 755 '{}' \;
	find /lib /lib64 /usr/lib -perm /022 -type f -exec chmod 755 '{}' \;
	find /var/log -perm /137 -type f -exec chmod 640 '{}' \;
	find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm /022 -type d -exec chmod -R 755 '{}' \;
	find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm /022 -type f -exec chmod 755 '{}' \;
	find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -user root -type d -exec chown root '{}' \;
	find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -user root -type f -exec chown root '{}' \;
	find /lib /usr/lib /lib64 ! -user root -type d -exec chown root '{}' \;
	find /lib /usr/lib /lib64 ! -group root -type d -exec chgrp root '{}' \;
	find /lib /usr/lib /lib64 ! -group root -type f -exec chgrp root '{}' \;
	find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -group root -type d -exec chgrp root '{}' \;
	find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin ! -group root -type f ! -perm /2000 -exec chgrp root '{}' \;
	
	# session lock
	gsettings set org.gnome.desktop.screensaver lock-enabled true

	chmod 0750 /var/log
	chown root /var/log
	chown syslog /var/log/syslog
	chgrp adm /var/log/syslog
	chmod 0640 /var/log/syslog
	chgrp syslog /var/log

	cp "/home/$username/Desktop/linux/autologout.sh" /etc/profile.d/

	echo "install usb-storage /bin/true" >> /etc/modprobe.d/DISASTIG.conf
	echo "blacklist usb-storage" >> /etc/modprobe.d/DISASTIG.conf

}

hacking_tools() {
	apt-get purge nmap* -y -qq
	apt-get purge netcat -y -qq
	apt-get purge netcat-openbsd -y -qq
	apt-get purge netcat-traditional -y -qq
	apt-get purge socket -y -qq
	apt-get purge sbd -y -qq
	apt-get purge john -y -qq
	apt-get purge hashcat -y -qq
	apt-get purge hydra -y -qq
	apt-get purge hydra-gtk -y -qq
	apt-get purge aircrack-ng -y -qq
	apt-get purge fcrackzip -y -qq
	apt-get purge lcrack -y -qq
	apt-get purge ophcrack -y -qq
	apt-get purge ophcrack-cli -y -qq
	apt-get purge pyrit -y -qq
	apt-get purge rarcrack -y -qq
	apt-get purge sipcrack -y -qq
	apt-get purge nfs-kernel-server -y -qq
	apt-get purge nfs-common -y -qq
	apt-get purge portmap -y -qq
	apt-get purge rpcbind -y -qq
	apt-get purge autofs -y -qq
	apt-get purge vnc4server -y -qq
	apt-get purge vncsnapshot -y -qq
	apt-get purge vtgrab -y -qq
	apt-get purge wireshark -y -qq
	apt-get purge cewl -y -qq
	apt-get purge medusa -y -qq
	apt-get purge wfuzz -y -qq
	apt-get purge sqlmap -y -qq
	apt-get purge snmp -y -qq
	apt-get purge crack -y -qq
	apt-get purge rsh-server -y -qq
	apt-get purge nis -y -qq
	apt-get purge prelink -y -qq
	apt-get purge backdoor-factory -y -qq
	apt-get purge shellinabox -y -qq
	apt-get purge at -y -qq
	apt-get purge xinetd -y -qq
	apt-get purge openbsd-inetd -y -qq
	apt-get purge talk -y -qq
	systemctl --now disable avahi-daemon
	systemctl --now disable isc-dhcp-server
	systemctl --now disable isc-dhcp-server6
	systemctl --now disable slapd
	apt-get purge ldap-utils -y -qq
	apt-get purge slapd -y -qq
	systemctl --now disable nfs-server
	apt-get purge nfs-server -y -qq
	systemctl --now disable rpcbind
	apt-get purge rpcbind -y -qq
	systemctl --now disable rsync
	apt-get purge rsync -y -qq
	apt-get autoremove -y -qq
	apt-get autoclean -y -qq
	apt-get clean -y -qq
}

record_files() {
	find /home -type f -name "$1" 2>/dev/null
	find /root -type f -name "$1" 2>/dev/null
}

media_files() {

	echo "#########Logging the file directories of media files in home directories on the machine#########"
	touch "${homeDir}/Desktop/logs/media_files.log"
	chmod 777 "${homeDir}/Desktop/logs/media_files.log"

	echo "Most common types of media files:" >> "${homeDir}/Desktop/logs/media_files.log"
	common=("*.midi" "*.mid" "*.mp3" "*.ogg" "*.wav" "*.mov" "*.wmv" "*.mp4" "*.avi" "*.swf" "*.ico" "*.svg" "*.gif" "*.jpeg" "*.jpg" "*.png" "*.doc*" "*.ppt*" "*.xl*" "*.pub" "*.pdf" "*.7z" "*.zip" "*.rar" "*.txt" "*.exe" "*.pcapng" "*.jar" "*.json")
	for i in "${common[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done

	echo "PHP files:" >> "${homeDir}/Desktop/logs/media_files.log"
	php=("*.php"  "*.php3" "*.php4" "*.phtml" "*.phps" "*.phpt" "*.php5")
	for i in "${php[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done

	echo "Script files:" >> "${homeDir}/Desktop/logs/media_files.log"
	script=("*.sh" "*.bash" "*.bsh" "*.csh" "*.bash_profile" "*.profile" "*.bashrc" "*.zsh" "*.ksh" "*.cc" "*.startx" "*.bat" "*.cmd" "*.nt" "*.asp" "*.vb" "*.pl" "*.vbs" "*.tab" "*.spf" "*.rc" "*.reg" "*.py" "*.ps1" "*.psm1" "*.c" "*.cs" "*.js" "*.html")
	for i in "${script[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done

	echo "Audio:" >> "${homeDir}/Desktop/logs/media_files.log"
	audio=("*.mod" "*.mp2" "*.mpa" "*.abs" "*.mpega" "*.au" "*.snd" "*.aiff" "*.aif" "*.sid" "*.flac")
	for i in "${audio[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done

	echo "Video:" >> "${homeDir}/Desktop/logs/media_files.log"
	video=("*.mpeg" "*.mpg" "*.mpe" "*.dl" "*.movie" "*.movi" "*.mv" "*.iff" "*.anim5" "*.anim3" "*.anim7" "*.vfw" "*.avx" "*.fli" "*.flc" "*.qt" "*.spl" "*.swf" "*.dcr" "*.dir" "*.dxr" "*.rpm" "*.rm" "*.smi" "*.ra" "*.ram" "*.rv" "*.asf" "*.asx" "*.wma" "*.wax" "*.wmx" "*.3gp" "*.flv" "*.m4v")
	for i in "${video[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done

	echo "Images:" >> "${homeDir}/Desktop/logs/media_files.log"
	images=("*.tiff" "*.tif" "*.rs" "*.rgb" "*.xwd" "*.xpm" "*.ppm" "*.pbm" "*.pgm" "*.pcx" "*.svgz" "*.im1" "*.jpe")
	for i in "${images[@]}"
	do
		record_files "$i" >> "${homeDir}/Desktop/logs/media_files.log"
	done
}

parse_readme() {
	touch "${homeDir}/Desktop/logs/changelog.log"
	chmod 777 "${homeDir}/Desktop/logs/changelog.log"
	echo "Please enter the link to the README"
	read -r link
	adminsList=$(python3 scraper.py "$link" admins)
	IFS=';' read -r -a admins <<< "$adminsList"
	usersList=$(python3 scraper.py "$link" users)
	IFS=';' read -r -a users <<< "$usersList"
	servicesList=$(python3 scraper.py "$link" services)
	IFS=';' read -r -a services <<< "$servicesList"
	echo "Authorized Administrators supposed to be on the system:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${admins[@]}"; do
		echo "$item" >>"${homeDir}/Desktop/logs/changelog.log"
	done
	echo "Authorized Standard Users supposed to be on the system:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${users[@]}"; do
		echo "$item" >>"${homeDir}/Desktop/logs/changelog.log"
	done
	echo "Services:"
	for item in "${services[@]}"; do
		echo "$item"
	done

	currentUserList=$(eval getent passwd "{$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)..$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)}" | cut -d: -f1 | tr '\n' ' ')
	IFS=' ' read -r -a currentUsers <<<"$currentUserList"
	authUserList="${adminsList} ${usersList}"
	authUsers=("${admins[@]}" "${users[@]}")

	for item in "${currentUsers[@]}"; do 
		if [[ "${item}" != "${username}" ]]; then
			usermod --password "$(echo M3rc1l3ss_cYp@t\!1 | openssl passwd -1 -stdin)" "${item}"
		fi
	done

	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "Users deleted off the system:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${currentUsers[@]}"; do
		if [[ "$authUserList" != *"$item"* ]]; then
			echo "${item}" >>"${homeDir}/Desktop/logs/changelog.log"
			echo "####Removing user ${item} from system####"
			deluser "${item}"
		fi
	done

	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "Users added to the system:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${users[@]}"; do
		if [[ "$currentUserList" != *"$item"* ]]; then
			echo "${item}" >>"${homeDir}/Desktop/logs/changelog.log"
			echo "####Adding user ${item}####"
			adduser --gecos "${item}"
		fi
	done

	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "Authorized admins given sudo permissions:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${admins[@]}"; do
		if [[ "$(groups "${item}")" != *"sudo"* ]]; then
			echo "${item}" >>"${homeDir}/Desktop/logs/changelog.log"
			usermod -aG sudo "${item}"
		fi
	done

	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "Authorized standard users stripped of sudo permissions:" >>"${homeDir}/Desktop/logs/changelog.log"
	for item in "${users[@]}"; do
		if [[ "$(groups "${item}")" == *"sudo"* ]]; then
			echo "${item}" >>"${homeDir}/Desktop/logs/changelog.log"
			gpasswd -d "${item}" sudo
		fi
	done

	for item in "${authUsers[@]}"; do
		usermod --shell /usr/sbin/nologin "${item}"
	done
	echo "All standard users are now in the 'NoLogin' Shell" >>"${homeDir}/Desktop/logs/changelog.log"

	rootUserList=$(grep :0: /etc/passwd | tr '\n' ' ')
	IFS=' ' read -r -a rootUsers <<<"$rootUserList"
	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "All current root users on the machine (should only be 'root')" >>"${homeDir}/Desktop/logs/changelog.log"
	for thing in "${rootUsers[@]}"; do
		echo "${thing%%:*}" >>"${homeDir}/Desktop/logs/changelog.log"
	done

	allUserList=$(cut -d ':' -f1 /etc/passwd | tr '\n' ' ')
	IFS=' ' read -r -a allUsers <<<"$allUserList"
	echo >>"${homeDir}/Desktop/logs/changelog.log"
	echo "All current users on the machine (make sure all users that look like normal users are authorized)" >>"${homeDir}/Desktop/logs/changelog.log"
	for thing in "${allUsers[@]}"; do
		echo "$thing" >>"${homeDir}/Desktop/logs/changelog.log"
	done

	for item in "${authUsers[@]}"; do
		crontab -u "$item" -r
	done
	echo "- Cleared crontab for all users" >>"${homeDir}/Desktop/logs/changelog.log"

	useradd -D -f 30
	for item in "${authUsers[@]}"; do
		chage --inactive 30 "$item"
	done
	echo "- Account inactivity policy set" >>"${homeDir}/Desktop/logs/changelog.log"
}

second_time_failsafe() {

	failYN=""
	while [ "$failYN" != "exit" ]; do

		echo "*********Which part of the script would you like to redo? (all, packages, firewall, services, hacking_tools, general_config, file_config, user_auditing, media_files) (type exit to leave)*********"
		read -r failYN
		if [[ $failYN == "all" ]]; then
			init
			packages
			parse_readme
			hacking_tools
			general_config
			services
			file_config
			firewall
			media_files
			clean
			audit
			end
			clamtk
		elif [[ $failYN == "packages" ]]; then
			packages
		elif [[ $failYN == "user_auditing" ]]; then
			parse_readme
		elif [[ $failYN == "firewall" ]]; then
			firewall
		elif [[ $failYN == "services" ]]; then
			services
		elif [[ $failYN == "hacking_tools" ]]; then
			hacking_tools
		elif [[ $failYN == "general_config" ]]; then
			general_config
		elif [[ $failYN == "file_config" ]]; then
			file_config
		elif [[ $failYN == "parse_readme" ]]; then
			parse_readme
		elif [[ $failYN == "media_files" ]]; then
			media_files
		else
			echo "####Option not found (or exiting)####"
		fi
	done
	exit 0

}

clean() {
	sysctl -p
	ufw reload
	apt-get update -y
	apt-get upgrade -y
	systemctl daemon-reload
	apt-get autoremove -y -qq
	apt-get autoclean -y -qq
	apt-get clean -y -qq
}

end() {
	echo "#########Creating symbolic link to /var/log/ in logs folder on Desktop#########"
	ln -s /var/log/ "${homeDir}/Desktop/logs/servicelogs"
	cp "${homeDir}/Desktop/linux/logs-to-check.txt" "${homeDir}/Desktop/logs/logs-to-check.txt"
	echo "- Created symbolic link to \/var\/log\/ in logs folder on Desktop" >>"${homeDir}/Desktop/logs/changelog.log"

	echo "Script done! Good luck :D"
}

failsafe=${homeDir}/Desktop/logs/changelog.log
if [[ -f "$failsafe" ]]; then
	echo "This script is detected as being run for more than one time"
	echo "This has been known to cause a wide variety of problems, including potential loss of internet, which in worst case scenario, can necessitate a restart of the image."
	echo "Luckily, a system has been implemented to avoid this problem"
	echo "Would you like to continue with choosing which parts of the script to redo?"
	read -r restartYN
	if [[ $restartYN == "yes" ]]; then
		echo "Would you like to remove and replace the current installments of the changelog and backups? (other option is creating new files)"
		read -r removeYN
		if [[ $removeYN == "yes" ]]; then
			rm -r "${homeDir}/Desktop/logs"
			first_time_initialize
			second_time_failsafe
		elif [[ $removeYN == "no" ]]; then

			echo "Replacing legacy folder and backing up old files"
			mkdir -p "${homeDir}/Desktop/logs_legacy"
			mv "${homeDir}/Desktop/logs" "${homeDir}/Desktop/logs_legacy"
			mv "${homeDir}/Desktop/logs/changelog.log" "${homeDir}/Desktop/logs_legacy"
			mv -r "${homeDir}/Desktop/logs/backups/" "${homeDir}/Desktop/logs_legacy"
			first_time_initialize
			second_time_failsafe
		else
			echo "Option not recognized"
			exit 1
		fi
	elif [[ $restartYN == "no" ]]; then
		echo "Exiting script"
		exit 0
	else
		echo "Option not recognized"
		exit 1
	fi
fi

echo "Type 'safe' to enter safe mode and anything else to continue"
read -r safecheck
if [[ $safecheck == "safe" ]]; then
	echo "Entering safe mode ..."
	echo "In safe mode, you can choose to only run certain parts of the script"
	second_time_failsafe
fi

#Calls for functions to run through individual portions of the script
init
packages
parse_readme
hacking_tools
general_config
services
file_config
firewall
media_files
clean
end
