#!/bin/bash

cd src  

# Crear infraestrucura
#terraform apply -auto-approve

# Determina variables de la infraestructura creada
bastion_ip=$(terraform output -raw bastion_ip)
rds_hostname=$(terraform output -raw rds-endpoint | sed 's/:3306//g')
rds_user=$(terraform output -raw rds-username)
rds_password=$(terraform output -raw rds-password)

echo "Bastion IP: $bastion_ip"
echo "RDS Hostname: $rds_hostname"

cd ..

scp -i ./tests/keys/id_rsa ./data/* ubuntu@$bastion_ip:/home/ubuntu/

ssh ubuntu@$bastion_ip -i ./tests/keys/id_rsa "chmod 777 /home/ubuntu/*.csv"

ssh ubuntu@$bastion_ip -i ./tests/keys/id_rsa "mysql -u $rds_user --password=$rds_password -h $rds_hostname -e 'CREATE DATABASE IF NOT EXISTS covid_db'"
ssh ubuntu@$bastion_ip -i ./tests/keys/id_rsa "mysql --local-infile=1  -u $rds_user --password=$rds_password -h $rds_hostname < /home/ubuntu/deaths.sql"
ssh ubuntu@$bastion_ip -i ./tests/keys/id_rsa "mysql --local-infile=1  -u $rds_user --password=$rds_password -h $rds_hostname < /home/ubuntu/vaccination.sql" 


gnome-terminal -e "ssh ubuntu@$bastion_ip -i ./tests/keys/id_rsa" > /dev/null 2>&1

# Copy mysql connection command to clipboard
echo "mysql -u admin --password=motomami -h $rds_hostname" | xclip -selection clipboard