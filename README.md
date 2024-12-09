# Projeto Wordpress-AWS-Docker

Este projeto fez parte das atividades de estágio no Studio de DevSecOps da Compass UOL, consistindo em efetuar deploy de uma aplicação do Wordpress conteinerizada em instâncias na AWS. Foram utilizadas algumas tecnologias como o Docker, Auto Scaling, EFS (Elastic File System) e LB (Load Balancer). O projeto precisou obrigatoriamente seguir a arquitetura fornecida pela Compass conforme mostrada abaixo:

![Arquitetura do projeto](https://github.com/user-attachments/assets/cc86fa8f-1ac4-4275-bdd0-dd33aad6c5d6)

Segue o passo a passo do projeto:

## 1) Criação da VPC (Virtual Private Cloud) e Subredes

A VPC é a rede virtual privada na Amazon onde estarão as subredes privadas e públicas da aplicação que vamos rodar. Para este projeto, escolhi usar 2 subredes públicas e 2 privadas a fim de aderir mais de perto a arquitetura proposta. No console da AWS, clicar em VPC e seguir até o dashboard da VPC. Clicar em "Create VPC". Usaremos as seguintes configurações na página de criação:

> VPC Settings

 * VPC and more
 * Name tag auto-generation (deixar o auto-generate marcado) e digitar o nome do projeto, no caso, "wordpress", pois este será o nome da VPC.
 * Number of Availability Zones (AZs): 2
 * Number of public subnets : 2
 * Number o private subnets: 2
 * NAT gateways: In 1 AZ
 * VPC endpoints: None

O restante das configurações permanece conforme o padrão.

Clicar em "Create VPC"

Após a criação, a VPC deverá possuir a seguinte topologia conforme a imagem:

![Topologia VPC](https://github.com/user-attachments/assets/478cb3c1-c9b2-45ca-891c-f8462c98df10)

## 2) Criação do Security Group

Um security group atua como um firewall virtual para as instâncias a fim de controlar o tráfego de
entrada e saída na rede. Configuraremos as regras de entrada e saída de tráfego através de cada protocolo e portas liberadas.
No próprio dashboard da VPC, na parte inferior esquerda, rolamos até a opção "Security Group" e depois clicamos em "Create security Group". Usamos as seguintes configurações:

> Basic details

Security group name: inserir um nome para o security group
Description: Firewall for VPC and instances
VPC: selecionar a VPC que acabamos de criar

> Inbound rules (nesta seção criaremos as regras de tráfego de entrada de rede)

Clicar em "Add rule" e ir adicionando as seguintes configurações:

| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| Custom TCP | TCP | 8080 | Anywhere-IPv4 |
| SSH | TCP | 22 | Anywhere-IPv4 |
| DNS (TCP) | TCP | 53 | Anywhere-IPv4 |
| HTTP | TCP | 80 | Anywhere-IPv4 |
| HTTPS | TCP | 443 | Anywhere-IPv4 |
| MYSQL/Aurora | TCP | 3306 | Anywhere-IPv4 |
| NFS | TCP | 2049 | Anywhere-IPv4 |

> Outbound rules (nesta seção criaremos as regras de tráfego de entrada de saída)

Clicar em "Add rule" e ir adicionando as seguintes configurações:

| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| Custom TCP | TCP | 8080 | Anywhere-IPv4 |
| SSH | TCP | 22 | Anywhere-IPv4 |
| DNS (TCP) | TCP | 53 | Anywhere-IPv4 |
| HTTP | TCP | 80 | Anywhere-IPv4 |
| HTTPS | TCP | 443 | Anywhere-IPv4 |
| MYSQL/Aurora | TCP | 3306 | Anywhere-IPv4 |
| NFS | TCP | 2049 | Anywhere-IPv4 |

Clicar em "Create security group"

## 3) Criação do EFS (Elastic File System)

O EFS é uma tecnologia da AWS que permite criar um sistema de arquivos elástico que cresce ou diminui automaticamente a capacidade de armazenamento de arquivos conforme as demandas de cada aplicação. No painel da AWS, devemos clicar em EFS para seguir até o dashboard e, na sequência, clicar em "Create File System" e depois em "Customize". Usaremos as seguintes configurações:

> File System Settings
* Name: Inserir um nome para o EFS
O restante das configurações permanece como padrão.
> Network Access
*  Virtual Private Cloud: Selecionar a VPC que criamos (wordpress-vpc)
   -  Mount Targets (Ponte de montagem 1)
      - Availability Zone: us-east-1a
      - Subnet ID: selecionar uma subrede "private"
      - Security Group: Wordpress-Firewall
  -  Mount Targets (Ponto de montagem 2)
      - Availability Zone: us-east-1b
      - Subnet ID: selecionar uma subrede "private"
      - Security Group: Wordpress-Firewall  

O restante das configurações de "File System Policy" e "Review and Update" permanecem como padrão. Clicar em "Create".

Na lista dos File Systems criados, podemos clicar no EFS que acabamos de criar e depois no botão "Attach", onde abrirar uma janela com informações para montarmos a EFS na instância EC2. Usaremos a opção "Mout via IP", dentro da Availability Zone "us-east-1a". Portanto, devemos guardar o comando citado abaixo da frase "Using the NFS cliente". Como exemplo, temos o comando:

````
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.128.237:/ /efs
````

O qual será usado para realizar a montagem via assistente NFS no Ubuntu, conforme veremos mais à frente na seção comentada "Montagem do EFS" do script user data.

## 4) Criação do banco de dados Amazon RDS (Relational Data Base)

Amazon RDS é um serviço da Amazon que facilita a configuração, operação e escalabilidade de um banco de dados relacional econômico e redimensionável na nuvem. Seguindo a arquitetura proposta no início, devemos criar um único banco de dados acessível pelas instâncias em zonas de disponibilidade diferentes. No painel da AWS, devemos clicar em RDS para seguir até o dashboard e, em seguida, clicar em "Create Database". Aplicaremos estas configurações:

> Database creation method: Standard

> Engine options: MySQL (conforme descrição do projeto Compass)

> Engine Version: 8.0.39

> Templates: Free tier (para teste de novas aplicações)
 
> Availability and durability: Single DB instance
 
> Settings
   * DB Instance Identifier: Inserir o nome da base de dados (Ex: wordpress-database-1)
   * Credentials Settings:
   * Master username: inserir o username (Ex: admin)
   * Credentials Management: Self managed
   * Master password: inserir uma senha para acesso à base de dados
     
> Instance Configuration
   * Busrtable classes: db.t3.micro
     
> Conectivity:

   * Virtual Private Cloud (VPC): selecionar a VPC criada no início (wordpress-vpc)
   * VPC Security Group (firewall): choose existing
      * Existing VPC security groups: selecionar o security group criado no início (Wordpress-Firewall)

 O restante das configurações permanece como o padrão. Clicar em "Create database" e aguardar alguns minutos até que a criação esteja concluída com o status "Available".

 ## 4) Criação dos Elastic IP para testes das instâncias

Conforme o descritivo do projeto pela Compass, o serviço do Wordpress deverá ser publicado em IP privado por questões de segurança. Contudo, podemos associar IPs públicos estáticos para testar a conexão e deploy do Wordpress nas instâncias através dos Elastic IPs, que são IPs públicos da AWS que podem ser associados e desassociados a diferentes tipos de instâncias.

No painel das ECS, no canto inferior direito, rolar até a opção "Elastic IPs" e clicar em "Allocate Elastic IP". Em "Network border group", clicar no grupo relativo às zonas de disponibilidade disponíveis para a rede que criamos e depois clicar em "Alocate". Este processo pode ser realizado várias vezes para alocar mais um IP em outra máquina da AWS ou até mesmo para Gateways NAT, conforme veremos mais à frente.

A fim de organizar os IPs públicos criados, podemos atribuir nomes a cada um deles. Para isso, na lista de Elastic IPs, basta clicar no campo "Name" que surgirá um novo campo para atribuir um nome.

## 5) Criação do script user data

É possível executar comandos ao iniciar uma instância EC2 para executar tarefas de instalação e configuração, ou para automatizar a criação das aplicações nas instâncias (como é o nosso caso), tudo realizado através de um script chamado *user data* ou *dados do usuário*. Após a realização de alguns testes, chegou-se ao seguinte user data a ser inserido no momento da criação da instância EC2:

```

#!/bin/bash

#Atualização dos pacotes com suas fontes

sudo apt update

#Atualização dos pacotes do sistema

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
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.128.237:/ /efs
sudo su
sudo echo "10.0.128.237:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

#Criação do container Wordpress

sudo mkdir /wordpress
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
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: adminwordpress1
      WORDPRESS_DB_NAME: database-wordpress
    volumes:
      - /efs/wordpress:/var/www/html

volumes:
  wordpress:
  db:
EOF

sudo docker-compose up -d

```

## 7) Criação do Key Pairs para conexão às instâncias EC2 (opcional)



## 8) Criação das Instâncias EC2 (Elastic Compute Cloud)

A Amazon oferece uma plataforma de computação chamada de Amazon Elastic Compute Cloud, ou simplesmete EC2, para criar máquinas virtuais chamadas de instâncias com diversas opções de processadores, armazenamento, redes e sistemas operacionais. A aplicação Wordpress será configurada usando a tecnologia de containers do docker dentro de cada instância EC2. Conforme o descritivo do projeto da Compass, podemos criar 2 instâncias EC2, cada uma em uma EZ (Availability Zone) distinta da outra. No painel da AWS, clicamos em "EC2" e seguimos para o dashboard de criação da instância.
