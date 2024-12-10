# Projeto Wordpress-AWS-Docker

Este projeto fez parte das atividades de estágio no Studio de DevSecOps da Compass UOL, consistindo em efetuar deploy de uma aplicação do Wordpress conteinerizada em instâncias na AWS. Foram utilizadas algumas tecnologias como o Docker, Auto Scaling, EFS (Elastic File System) e LB (Load Balancer). O projeto precisou obrigatoriamente seguir a arquitetura fornecida pela Compass conforme mostrada abaixo:

![Arquitetura do projeto](https://github.com/user-attachments/assets/0c1bb0f5-a65a-4a40-92a2-927d5cd1bab3)

Segue o passo a passo do projeto:

## 1) VPC (Virtual Private Cloud) e Subredes

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

## 2) Security Group

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

## 3) EFS (Elastic File System)

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

## 4) Banco de dados Amazon RDS (Relational Data Base)

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

 ## 4) Elastic IP para testes das instâncias

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
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.135.121:/ /efs
sudo su
sudo echo "10.0.135.121:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab
exit

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

## 7) Key Pairs para conexão às instâncias EC2

Podemos nos conectar às instâncias EC2 através de nossa máquina local utilizando protocolo SSH para realizar tarefas de manutenção nas instâncias remotamente. Para isso, será preciso gerar um Key Pair, um arquivo para baixarmos e utilizar como chave-segredo para realizar a conexão remota. No dashboard da EC2, rolar na parte inferior esquerda da seção "NetWork and Security" até a opção "Key Pairs". Usaremos as seguintes configurações:

* Name: inserir um nome para a chave
* Key pair type: RSA
* Private key file format: .pem (é possível usar o formato .ppk, caso utilize o PuTTy para conexão remota)

Clique em "Create key pair" e será aberta uma janela para salvar o arquivo .pem em sua máquina local. Após salvar, copie a chave para a pasta raiz no seu sistema operacional, pois facilita posteriormente o reconhecimento da mesma quando utilizarmos o comando para a conexão SSH. Será preciso atribuir uma permissão ao arquivo .pem para conseguirmos estabelecer a conexão SSH, para isso, utilize o comando:

````
sudo chmod 400 nomedachave.pem
````


## 8) Criação das Instâncias EC2 (Elastic Compute Cloud)

A Amazon oferece uma plataforma de computação chamada de Amazon Elastic Compute Cloud, ou simplesmete EC2, para criar máquinas virtuais chamadas de instâncias com diversas opções de processadores, armazenamento, redes e sistemas operacionais. A aplicação Wordpress será configurada usando a tecnologia de containers do docker dentro de cada instância EC2. Conforme o descritivo do projeto da Compass, podemos criar 2 instâncias EC2, cada uma em uma EZ (Availability Zone) distinta da outra. No painel da AWS, clicamos em "EC2" e seguimos para o dashboard de criação da instância. Clique em "Launch Instances" e, na tela de criação, usaremos os seguintes parâmetros para criar a instância:

> Name and tags (clicar em Add additional tags)
  Usaremos um conjunto de 3 tags (Name, CostCenter, Project) conforme fornecidas pela Compasso:
  (1)
  * Key: Name
  * Value: Inserir um nome para a instância (ex.: Wordpress-Instance1)
  * Resource types: marcar "Instances" e "Volumes"
  (2)
  * Key: CostCenter
  * Value: conforme fornecido pela Compass
  * Resource types: marcar "Instances" e "Volumes"
  (3)
  * Key: Project
  * Value: conforme fornecido pela Compass
  * Resource types: marcar "Instances" e "Volumes"

> Application and OS images
  * Ubuntu Noble 24.04 amd64 (Free tier eligible)

> Instance type
  *t2.micro (Free tier eligible)

> Key pair (login)
  * Key pair name: usar a key pair criada na etapa anterior

> Network settings (clicar em Edit)
  * VPC: usar a VPC criada
  * Subnet: usar uma subnet pública, preferencial na zona us-east-1a
  * Auto-assign public IP: Disable
  * Firewall (security groups)
    * Select existing security group: selecionar o security group criado inicialmente (Wordpress-Firewall)

> Advanced Details
  * User data: Neste campo vamos inserir o script user data para automatizar as tarefas de instalação do docker e Wordpress na inicialização da EC2. Podemos copiar e colar ou realizar uploado do arquivo.

Clicar em "Launch Instance" e depois em "View all Instances". Aguardar o processo de criação e validação da instância, acompanhando pelo painel.

Após o processo de validação da Instância, podemos atribuir um IP elástico a mesma para realizar a conexão SSH e verificar o estado da máquina antes de iniciar o serviço Wordpress. Para isso, vamos até a parte inferior esquerda do dashboard EC2, na seção "Network and Security" clique em "Elastic IPs". Selecione o IP criado anteriormente para a instância, clique em "Actions" e depois em "Associate Elastic IP adress".
Na janela que se segue, selecione a Instância que está rodando, o IP privado e clique em "Associate".
