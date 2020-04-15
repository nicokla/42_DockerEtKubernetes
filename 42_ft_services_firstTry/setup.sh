# -------------------------
# 0) Prerequisites

# TODOs before launching script :
# - Install : virtualbox, docker-machine, docker, minikube, kubectl, helm, jq
# Also update helm : helm repo add stable https://kubernetes-charts.storage.googleapis.com; helm repo update;
# (docker should not be "docker for mac", because it doesn't use virtualbox, so it seems 
# docker can't be linked to minikube properly with it. Instead you can install docker via MSC or brew.)
# - Launch minikube if not already done :
# minikube status
# minikube start --cpus=4 --memory 4000 --disk-size 11000 --vm-driver virtualbox --extra-config=apiserver.service-node-port-range=1-35000

# 0.1) Function to wait for deployment
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

# 0.2) Cleaning, old way --> too brutal for helm, now use clean.sh
# kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all; 
# read -n 1 -s -r -p "Delete helm ressources if necessary in another terminal, then click enter."
kubectl get all
chmod u+x clean.sh
while true; do
    read -p "Do you wish to clean before building ? Answer by y or n:" yn
    case $yn in
        [Yy]* ) sh ./clean.sh; break;;
        [Nn]* ) break;; # exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# 0.3) Set docker environment as minikube, so that kubernetes see the images built by docker.
eval $(minikube docker-env);


# -------------------------
# 1) Deploy services

# ----------------
# 1.1) InfluxDB, Grafana
# https://youtu.be/GLE71pIHUU8
# https://octoperf.com/blog/2019/09/19/kraken-kubernetes-influxdb-grafana-telegraf/
# https://www.youtube.com/watch?v=Fabdhg_WMVU
# https://medium.com/faun/total-nginx-monitoring-with-application-performance-and-a-bit-more-using-8fc6d731051b

printf "Deploy InfluxDB\n"
helm install -f srcs/influxdb.yaml influxdb stable/influxdb
wait_for_deploy influxdb

printf "Deploy Grafana\n"
helm install -f srcs/grafana.yaml grafana stable/grafana 
wait_for_deploy grafana

# ----------------
# 1.2) MySQL, Wordpress, PhpMyAdmin

printf "Deploy MySQL\n"
kubectl apply -f srcs/mysql.yaml
wait_for_deploy mysql

printf "Deploy Wordpress\n"
kubectl apply -f srcs/wordpress.yaml
wait_for_deploy wordpress

printf "Deploy PhpMyAdmin\n"
kubectl apply -f srcs/phpmyadmin.yaml
wait_for_deploy phpmyadmin

# -----------------
# 1.3) NGINX, Ingress Controller

printf "Build NGINX Image\n"
docker build -t nginx_ssh srcs/nginx
printf "Deploy NGINX\n"
kubectl create secret generic ssl-keys --from-file=srcs/nginx/keys/nginx.crt --from-file=srcs/nginx/keys/nginx.key
# kubectl create secret generic ssh-keys --from-file=srcs/nginx/keys/ssh_host_dsa_key --from-file=srcs/nginx/keys/ssh_host_dsa_key.pub  --from-file=srcs/nginx/keys/ssh_host_rsa_key --from-file=srcs/nginx/keys/ssh_host_rsa_key.pub --from-file=srcs/nginx/sshd_config
# kubectl create configmap nginx-config-map --from-file=srcs/nginx/nginx.conf
kubectl apply -f srcs/nginx.yaml
# grep -vwE "192.168.99" ~/.ssh/known_hosts > ~/.ssh/temp && mv ~/.ssh/temp ~/.ssh/known_hosts
# --> Is necessary only if the SSH keys are generated in the dockerfile, 
# because it causes them to change each time the dockerfile is rebuilt, 
# so after rebuild, the public keys don't match the old ones in .ssh/known_hosts,
# which creates an error when launching ssh
wait_for_deploy nginx

printf "Deploy Ingress\n"
minikube addons enable ingress
kubectl apply -f srcs/ingress.yaml
printf "Waiting for Ingress...\n"
sleep 10s

printf "Deploy Ingress Controller\n"
helm install -f srcs/nginx-ingress.yaml nginx-ingress stable/nginx-ingress
# wait_for_deploy nginx-ingress # not working, because of the '-' character
read -n 1 -s -r -p "In another terminal, check (with kubectl get pods) if nginx-ingress is ready,\
 then click enter (or any other key) in this terminal, to continue running this script."

# --------------------------------
# 1.4) FTPS Server
export KUB_IP=$(minikube ip)
# echo "\npasv_address=$KUB_IP" >> ./ftps/vstpd.conf
echo "\nThe minikube ip is : $KUB_IP\n"
read -n 1 -s -r -p "Verify that the IP in srcs/ftps/vsftpd.conf is correct, \
and replace it if necessary. Then, click enter."
printf "\nBuild FTPS Image\n"
docker build -t ftps_server srcs/ftps
printf "Deploy FTPS Server\n"
kubectl apply -f srcs/ftps.yaml
wait_for_deploy ftps

# ----------------------------------------
# 1.5) Setup wordpress

export KUB_IP=$(minikube ip)
export WP_POD=$(kubectl get pods | grep wordpress | cut -d" " -f1)
echo "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"| (kubectl exec $WP_POD -it /bin/sh)
echo "chmod +x wp-cli.phar" | (kubectl exec $WP_POD -it /bin/sh)
echo "mv wp-cli.phar /usr/local/bin/wp" | (kubectl exec $WP_POD -it /bin/sh)
echo "wp core install --path=/var/www/html --url=$KUB_IP:5050 --title="WP-CLI" --admin_user=admin --admin_password=password --admin_email=info@wp-cli.org --allow-root"| (kubectl exec $WP_POD -it /bin/sh)
echo "wp user create user1 user1@example.com --user_pass=password --role=author --allow-root"| (kubectl exec $WP_POD -it /bin/sh)
echo "wp user create user2 user2@example.com --user_pass=password --role=author --allow-root"| (kubectl exec $WP_POD -it /bin/sh)

# --------------------
# 2) Test services

# 2.0) See the pods, deployment, services
kubectl get all

# 2.1) Browser : all 3 services should be accessible from Chrome
# Wordpress (port 5050) / PhpMyAdmin (port 5000) / Grafana (port 3000, username: admin, pwd: admin)
echo "The minikube ip is : $KUB_IP\n\n"

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