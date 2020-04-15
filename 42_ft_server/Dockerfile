FROM debian:buster
ENV PASSWORD 'password'
ENV USER_WORDPRESS 'nicolas'
RUN apt-get update

# nginx and php packages
RUN apt-get install -y nginx wget procps psmisc debconf debconf-utils perl lsb-release gnupg
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y \
php php-cgi php-mysqli php-pear php-mbstring php-gettext \
php-common php-phpseclib php-mysql

# mysql
RUN apt-get update
RUN wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.9-1_all.deb
RUN echo "mysql-server-5.7 mysql-server/root_password password $PASSWORD" | debconf-set-selections
RUN echo "mysql-server-5.7 mysql-server/root_password_again password $PASSWORD" | debconf-set-selections
RUN export DEBIAN_FRONTEND=noninteractive && dpkg -i mysql-apt-config*
RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -q -y mysql-server

# php my admin
RUN apt-get update && apt-get install -y unzip
RUN cd /tmp && wget https://files.phpmyadmin.net/phpMyAdmin/4.9.1/phpMyAdmin-4.9.1-all-languages.zip ;\
 apt-get update ;\
 unzip * ; \
 mv phpMyAdmin-4.9.1-all-languages phpmyadmin ; \
 mv phpmyadmin /var/www/html/phpmyadmin
RUN apt-get install -y php-fpm

# wordpress
RUN cd /tmp ; \
 rm * ; \
 wget wordpress.org/latest.tar.gz ;\
 tar xvf latest.tar.gz ;\
 mv wordpress /var/www/html ;\
 cd /var/www/html/wordpress

# nginx configuration files
ADD ./srcs/www.conf /etc/php/7.3/fpm/pool.d/
ADD ./srcs/index.html /var/www/html
ADD ./srcs/default /etc/nginx/sites-available/
RUN chown -R www-data:www-data /var/www/html/wordpress

# ssl open ports (?) If you are not using a firewall, you can skip ahead to the next section
# sudo firewall-cmd --add-service=http
# sudo firewall-cmd --add-service=https
# sudo firewall-cmd --runtime-to-permanent
# sudo iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
#s udo iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# ssl generate key and certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-subj '/C=FR/ST=75/L=Paris/O=42/CN=nklarsfe' \
-keyout /etc/ssl/certs/localhost.key -out /etc/ssl/certs/localhost.crt

# create sql data base and start server
CMD  service mysql start; \
 service nginx start; \
 service php7.3-fpm start; \
 mysql -u root -p$PASSWORD -e "CREATE USER '$USER_WORDPRESS'@'localhost' identified by '$PASSWORD';" ;\
 mysql -u root -p$PASSWORD -e "CREATE DATABASE wordpress;"; \
 mysql -u root -p$PASSWORD -e "GRANT ALL PRIVILEGES ON wordpress.* TO '$USER_WORDPRESS'@'localhost';" ;\
 mysql -u root -p$PASSWORD -e "FLUSH PRIVILEGES;" ;\
 sleep infinity & wait
EXPOSE 8080 80 3306 33060 443
#nginx config et php-fpm config