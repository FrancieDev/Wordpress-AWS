#!/bin/bash

#Atualização dos pacotes com suas fontes e do sistema

sudo apt update
sudo apt upgrade -y

#Instalação do Docker e Docker Compose

sudo apt install docker.io -y
sudo service docker start
sudo systemctl enable docker
sudo curl -SL https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#Montagem do EFS

sudo apt-get -y install nfs-common
sudo mkdir /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.141.76:/ /efs
sudo chmod 666 /etc/fstab
sudo echo "10.0.141.76:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

#Criação do container Wordpress

sudo mkdir /wordpress
sudo chmod 666 /wordpress
sudo chmod +x /wordpress
cd /wordpress
sudo cat > docker-compose.yml << EOF
version: '3.1'

services:

  wordpress:
    image: wordpress
    restart: always
    ports:
      - 8080:80
    environment:
      WORDPRESS_DB_HOST: /inserir o endpoint da rds/
      WORDPRESS_DB_USER: /inserir usuario/
      WORDPRESS_DB_PASSWORD: /inserir senha de acesso/
      WORDPRESS_DB_NAME: /inserir nome da base de dados/
    volumes:
      - /efs/wordpress:/var/www/html

volumes:
  wordpress:
  db:
EOF

sudo docker-compose up -d
