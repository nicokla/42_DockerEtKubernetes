#!/bin/sh

wait_for_deploy () {
	printf "\e[0;34mWaiting for \e[0;35m"$1"\e[0;34m...\e[0m"
	sleep 5s
	export "$1"_POD=$( kubectl get pods -l app=$1 -o custom-columns=:metadata.name | tr -d '[:space:]' )
	export POD_TEMP=${1}_POD
	while [ "$( kubectl get pod ${!POD_TEMP} -o json | jq ".status.containerStatuses[0].ready" | tr -d '[:space:]' )" != "true" ]; do
		printf "\e[0;34m.\e[0m"
		sleep 5s
		export "$1"_POD=$( kubectl get pods -l app=$1 -o custom-columns=:metadata.name | tr -d '[:space:]' )
		export POD_TEMP=${1}_POD
	done
	sleep 2s
	printf "\e[0;34mDONE\e[0m\n"
}


# Ensure docker and minikube are installed
if ! which docker >/dev/null 2>&1 ||
    ! which minikube >/dev/null 2>&1
then
    echo Please install Docker and Minikube
    exit 1
fi

# Ensure minikube is launched
if ! minikube status >/dev/null 2>&1
then
    echo Minikube is not started! Starting now...
    if ! minikube start --vm-driver=virtualbox \
        --cpus 3 --disk-size=30000mb --memory=3000mb \
		--extra-config=apiserver.service-node-port-range=1-32767
    then
        echo Cannot start minikube!
        exit 1
    fi
    minikube addons enable metrics-server
    minikube addons enable ingress
fi

# Prerequisites
eval $(minikube docker-env)
KUB_IP=$(minikube ip)
cp srcs/ftps/vsftpd.conf_model srcs/ftps/vsftpd.conf
sed -i '' "s/##KUB_IP##/$KUB_IP/g" srcs/ftps/vsftpd.conf
cp srcs/wordpress/wordpress_model.sql srcs/wordpress/wordpress.sql
sed -i '' "s/##KUB_IP##/$KUB_IP/g" srcs/wordpress/wordpress.sql

# Launch or clean
if [ "$1" = "delete" ]
then
    kubectl delete -k srcs
	helm delete grafana
	helm delete influxdb
else
	helm install -f srcs/influxdb.yaml influxdb stable/influxdb
    wait_for_deploy influxdb

    helm install -f srcs/grafana.yaml grafana stable/grafana
    wait_for_deploy grafana

	docker build -t nginx_ssh srcs/nginx
	docker build -t ftps_server srcs/ftps
	docker build -t custom-wordpress:1.9 srcs/wordpress
	docker build -t custom-phpmyadmin:1.1 srcs/phpmyadmin
	docker build -t custom-mysql:1.11 srcs/mysql

    kubectl apply -k srcs
fi


# --------------------
# 2) Test services

# 2.0) See the pods
kubectl get pod

# 2.1) Browser : all 3 services should be accessible from Chrome
# Wordpress (port 5050) / PhpMyAdmin (port 5000) / Grafana (port 3000, username: admin, pwd: admin)
echo "\nThe minikube ip is : $KUB_IP\n\n"

# 2.2) Dashboard
# minikube dashboard

# 2.3) SSH connexion to the nginx service should work (pwd: password, cf Dockerfile)
# export KUB_IP=$(minikube ip)
# ssh -v root@$KUB_IP -p 32022

# 2.4) FTPS Server (in the FTPS Service)
# Put a file using filezilla (ip=$KUB_IP,user=admin,pwd=pass1234,port=21), 
# Then :
# export POD=$(kubectl get pod | grep ftps | cut -d" " -f1)
# echo "ls /ftps/data/admin" | (kubectl exec -it $POD -- /bin/sh)

# --------------------
# 3) Optional

# 3.1) Update html and see the result in Chrome
# kubectl get pod
# export POD=nginx-5c47d4568b-ptrgg   (replace it by your nginx pod name)
# kubectl cp srcs/nginx/index.html $POD:/usr/share/nginx/html/

# 3.2) change a config file and restart a service
# kubectl get pod
# export POD=...
# kubectl cp path_to_file $POD:folder_in_pod
# kubectl exec -it $POD -- /bin/sh
# sudo systemctl restart ...

# --------------------
# 4) Brouillon

# cat /var/log/nginx/error.log
# /etc/nginx/nginx.conf
# /usr/share/nginx/html/index.html
# /var/www/html
# sudo systemctl restart nginx
# kubectl replace -f ...