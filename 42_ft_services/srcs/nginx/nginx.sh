#!/bin/sh

/usr/sbin/sshd -D &
nginx &
/usr/bin/telegraf &
exec "$@"