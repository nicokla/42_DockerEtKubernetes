FROM alpine:3.10.3

RUN apk --update --no-cache add vsftpd openssl && \
	rm -rf /tmp/* /var/cache/apk/*
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY docker-entrypoint.sh /usr/local/bin

EXPOSE 20 21 32099 32100
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["tail", "-F", "/var/log/vsftpd.log"]