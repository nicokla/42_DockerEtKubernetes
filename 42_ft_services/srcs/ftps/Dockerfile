FROM alpine:3.10.3

RUN apk --update --no-cache add vsftpd openssl && \
	rm -rf /tmp/* /var/cache/apk/*
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY docker-entrypoint.sh /usr/local/bin


# --------------
# --> telegraf

COPY telegraf.tar.gz .
COPY telegraf.conf /etc/telegraf/
RUN tar -C . -xzf telegraf.tar.gz; \
	chmod +x telegraf/*; \
	cp telegraf/telegraf /usr/bin/; \
	rm -rf *.tar.gz* telegraf/

# ---------------

EXPOSE 20 21 32099 32100
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["tail", "-F", "/var/log/vsftpd.log"]