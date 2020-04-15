FROM wordpress:php7.4-fpm-alpine

RUN apk update && \
	apk add nginx mysql-client

COPY nginx.conf /etc/nginx/nginx.conf
COPY wordpress.sql /wordpress.sql
COPY entrypoint /entrypoint

# --------------
# --> telegraf

COPY telegraf.tar.gz .
COPY telegraf.conf /etc/telegraf/
RUN tar -C . -xzf telegraf.tar.gz; \
	chmod +x telegraf/*; \
	cp telegraf/telegraf /usr/bin/; \
	rm -rf *.tar.gz* telegraf/

# rm -f /var/log/nginx/access.log; \
RUN  touch /var/log/nginx/access.log;


#----------

ENTRYPOINT sh /entrypoint

CMD ["tail", "-F", "/var/log/nginx/access.log"]