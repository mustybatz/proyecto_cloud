#!/bin/bash

echo "RDS_HOSTNAME=${rds_hostname}" > /tmp/.env


sudo apt update && sudo apt install nginx curl build-essential git -y

curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -

sudo apt install nodejs

npm install -g pm2

cd /opt

git clone https://github.com/mustybatz/covid_api.git

cp /tmp/.env /opt/covid_api/.env

cd /opt/covid_api

npm install

sudo pm2 start src/index.js

sudo pm2 startup

sudo pm2 save
