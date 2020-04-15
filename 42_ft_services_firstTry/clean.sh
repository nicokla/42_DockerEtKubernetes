#!/bin/bash
printf "Cleaning\n"
printf "Remove FTPS Server\n"
kubectl delete -f srcs/ftps.yaml
printf "Remove Ingress\n"
kubectl delete -f srcs/ingress.yaml
printf "Remove Ingress Controller\n"
helm delete nginx-ingress
printf "Remove NGINX\n"
kubectl delete secret ssl-keys
# kubectl delete secret ssh-keys
# kubectl delete configmap nginx-config-map
kubectl delete -f srcs/nginx.yaml
printf "Remove PHPMyAdmin\n"
kubectl delete -f srcs/phpmyadmin.yaml
printf "Remove Wordpress\n"
kubectl delete -f srcs/wordpress.yaml
printf "Remove MySQL\n"
kubectl delete -f srcs/mysql.yaml
printf "Remove Grafana\n"
helm delete grafana
printf "Remove InfluxDB\n"
helm delete influxdb
printf "Done\n"