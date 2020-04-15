#!/bin/sh

# /usr/sbin/sshd
# nginx -g "daemon off;"
# /usr/bin/telegraf

/usr/sbin/sshd -D &
nginx &
/usr/bin/telegraf &
exec "$@"