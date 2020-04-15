#!/bin/sh

echo "# FTPS Server"

echo "## Creating empty log file"
touch /var/log/vsftpd.log

echo "## Generate certifcate"
openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=FR/ST=fr/L=Paris/O=42/CN=name" -keyout /etc/ssl/certs/vsftpd.pem -out /etc/ssl/certs/vsftpd.pem
chmod 600 /etc/ssl/certs/vsftpd.pem

echo "## Adding users"
mkdir -p /ftps/empty
mkdir -p /ftps/data
addgroup admin
adduser -D --ingroup admin admin
echo "admin:pass1234" | chpasswd
echo "root:pass1234" | chpasswd

echo "## Set folders permissions"
chmod 555 /ftps/empty
mkdir -p /ftps/data
chmod a-w /ftps/data
mkdir -p /ftps/data/root
chown -R root:root /ftps/data/root
mkdir -p /ftps/data/admin
chown -R admin:admin /ftps/data/admin


echo "## Listening..."

/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &
/usr/bin/telegraf &
exec "$@"