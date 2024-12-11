# Projeto de aplicação Wordpress em AWS-Docker

Este projeto fez parte das atividades de estágio no Studio de DevSecOps da Compass UOL, consistindo em efetuar deploy de uma aplicação do Wordpress conteinerizada em instâncias na AWS. Foram utilizadas algumas tecnologias como o Docker, Auto Scaling, EFS (Elastic File System) e LB (Load Balancer). O projeto precisou obrigatoriamente seguir a arquitetura fornecida pela Compass conforme mostrada abaixo:

![Arquitetura do projeto](https://github.com/user-attachments/assets/0c1bb0f5-a65a-4a40-92a2-927d5cd1bab3)

Segue o passo a passo do projeto:

## 1) VPC (Virtual Private Cloud) e Subredes

A VPC é a rede virtual privada na Amazon onde estarão as subredes privadas e públicas da aplicação que vamos rodar. Para este projeto, escolhi usar 2 subredes públicas e 2 privadas a fim de aderir mais de perto a arquitetura proposta. No console da AWS, clicar em VPC e seguir até o dashboard da VPC. Clicar em "Create VPC". Usaremos as seguintes configurações na página de criação:

> VPC Settings

 * VPC and more
 * Name tag auto-generation (deixar o auto-generate marcado) e digitar o nome do projeto, no caso, "wordpress-vpc", pois este será o nome da VPC.
 * Number of Availability Zones (AZs): 2
 * Number of public subnets : 2
 * Number o private subnets: 2
 * NAT gateways: None (será criado depois)
 * VPC endpoints: None

O restante das configurações permanece conforme o padrão. Clicar em "Create VPC". Após a criação, devemos editar a tabela de rotas da VPC para fazer as associações corretas das subnets, rotas e gateway. Para isso, clicamos em "Route tables" onde aparece a lista das rotas. É possível renomear as rotas para um nome mais amigável, onde no projeto usaremos "route-public" para a rota da rede pública e "route-private" para a rota da rede privada. Começando pela route-public, clicamos nela e depois em "Edit routes" onde ali fazemos a associação para o Internet Gateway "igw". O mesmo será feito na route-private, porém neste momento a rota privada não terá uma NAT gateway para acesso à internet pelas máquinas privadas. Esta etapa será feita mais à frente.

Após a criação e edição das rotas, a VPC deverá possuir a seguinte topologia conforme a imagem:

![Topologia VPC](https://github.com/user-attachments/assets/0ead1260-2c22-4725-a886-add914fbf4b8)

## 2) Security Group

Um security group atua como um firewall virtual para as instâncias a fim de controlar o tráfego de entrada e saída na rede. Configuraremos as regras de entrada e saída de tráfego através de cada protocolo e portas liberadas. No próprio dashboard da VPC, na parte inferior esquerda, rolamos até a opção "Security Group" e depois clicamos em "Create security Group". Por questões de segurança, criaremos um security group para cada tipo de instância em nosso projeto: EC2 Privada, Bastion Host, RDS, EFS e Load Balancer.

Usamos as seguintes configurações na criação dos security groups:

> Basic details

Security group name: inserir um nome do respectivo security groups (private-instance, bastion host, EFS, RDS ou Load Balancer)
Description: Firewall for VPC and instances
VPC: selecionar a VPC que acabamos de criar

As regras de tráfego de entrada (inbound rules) e saída (outbound rules) dos security groups devem ser definidas nesta parte. Portanto, em cada security group, usar os seguintes parâmetros:


**EC2 PRIVADA**

**Inbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| Custom TCP | TCP | 8080 | Load Balancer (security group) |
| SSH | TCP | 22 | Bastion Host (security group) |
| HTTP | TCP | 80 | Load Balancer (security group) |
| HTTPS | TCP | 443 | Load Balancer (security group) |
| MYSQL/Aurora | TCP | 3306 | RDS (security group) |
| NFS | TCP | 2049 | EFS (security group) |

**Outbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| All traffic | All | All | Anywhere IPV4 |

----------------------------------------------

**BASTION HOST**

**Inbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| SSH | TCP | 22 | 0.0.0.0/0 |

**Outbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| All traffic | All | All | Anywhere IPV4 |

----------------------------------------------

**RDS**

**Inbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| MYSQL/Aurora | TCP | 3306 | private-instance (security group) |

**Outbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| All traffic | All | All | Anywhere IPV4 |

----------------------------------------------

**EFS**

**Inbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| NFS | TCP | 2049 | private-instance (security group) |

**Outbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| All traffic | All | All | Anywhere IPV4 |

----------------------------------------------

**LOAD BALANCER**

**Inbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| HTTPS | TCP | 443 | 0.0.0.0/0 |
| HTTP | TCP | 80 | 0.0.0.0/0 |

**Outbound Rules**
| Type | Protocol | Port Range | Source |
| :---: | :---: | :---: | :----: |
| All traffic | All | All | Anywhere IPV4 |


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

Na lista dos File Systems criados, podemos clicar no EFS que acabamos de criar e depois no botão "Attach", onde abrirar uma janela com informações para montarmos a EFS na instância EC2. Usaremos a opção "Mout via IP", dentro da Availability Zone "us-east-1a". Portanto, devemos guardar o comando citado abaixo da frase "Using the NFS client". Como exemplo, temos o comando:

````
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.135.121:/ /efs
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

> Additional configuration:
  * Initial database name: inserir um nome para a base de dados

 O restante das configurações permanece como o padrão. Clicar em "Create database" e aguardar alguns minutos até que a criação esteja concluída com o status "Available".

## 5) Script user data

É possível executar comandos ao iniciar uma instância EC2 para automatizar a execução de tarefas de instalação e configuração das máquinas virtuais. Tal automatização é feita através de um shell script chamado de *user data* ou *dados do usuário* contendo todos os comandos que devem ser realizados na inicialização de uma nova instância. Após a realização de alguns testes, chegou-se ao seguinte user data que será comentado em detalhes abaixo.

A primeira parte do script executa a atualização dos pacotes instalados com suas fontes e a atualização dos pacotes do sistema Linux: 

```

#!/bin/bash

#Atualização dos pacotes com suas fontes e do sistema

sudo apt update
sudo apt upgrade -y

```

A segunda parte do script executa comandos na seguinte ordem: baixar e instalar os pacotes de instalação do docker, iniciar o serviço do docker, habilitar o serviço do docker na inicialização do sistema, baixar e instalar os pacotes do docker-compose e alterar a permissão do diretório do docker-compose para execução de scripts.

```

#Instalação do Docker e Docker Compose

sudo apt install docker.io -y
sudo service docker start
sudo systemctl enable docker
sudo curl -SL https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

```

A terceira parte do script executa comandos na seguinte ordem: baixar e instalar os pacotes do nfs-common (utilitário para montagem do EFS), criar um diretório para a montagem do EFS, executar a montagem do EFS a partir do comando de montagem fornecido pela AWS conforme mostrado na Etapa 3, alterar a permissão do diretório fstab para leitura e escrita, inserir no arquivo fstab as informações do EFS através do comando "echo" fazendo com que o NFS seja sempre iniciado junto com o reinício da instância.

```

#Montagem do EFS

sudo apt-get -y install nfs-common
sudo mkdir /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.141.76:/ /efs
sudo chmod 666 /etc/fstab
sudo echo "10.0.141.76:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

```

A quarta parte do script executa comandos na seguinte ordem: criar um diretório para armazenar o arquivo de manifesto docker-compose.yml, atribuir permissão de leitura e escrita ao diretório criado, atribuir permissão de execução de script ao diretório, acessar o diretório criado, criar um arquivo de manifesto docker-compose.yml que baixará a imagem do wordpress e iniciará o serviço de conteiner no docker através do comando cat junto com o parâmetro EOF, e por último, executa o comando para iniciar o serviços conteinerizados que foram declarados no arquivo docker-compose.yml

```

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

```

O arquivo deste script user data pode ser acessado na íntegra na 

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

## 9) Bastion Host

Para acessarmos as instâncias privadas, será necessário a criação de uma máquina separada chamada de Bastion Host. Esta máquina estará alocada em uma subnet pública da VPC do projeto onde poderemos acessá-la remotamete via SSH e, por meio da mesma, acessar remotamente a instância privada da aplicação para realizar tarefas de manutenção.

No painel da EC2, clicar em "Launch Instance" e usar as seguintes configurações:

> Name and tags (clicar em Add additional tags)
  Usaremos um conjunto de 3 tags (Name, CostCenter, Project) conforme fornecidas pela Compasso:
  (1)
  * Key: Name
  * Value: Inserir um nome para o bastion host (ex.: Sebastião Host)
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
    * Select existing security group: selecionar o security group criado para bastion host

Após a validação da Instância, podemos atribuir um IP elástico ao Bastion Host para realizar a conexão SSH. Para isso, vamos até a parte inferior esquerda do dashboard EC2, na seção "Network and Security" clique em "Elastic IPs". Selecione o IP criado anteriormente para a instância, clique em "Actions" e depois em "Associate Elastic IP adress". Na janela que se segue, selecione a Instância do Bastion Host, o IP privado e clique em "Associate".

Agora será possível acessar as instâncias privadas através do Bastion Host, bastando apenas copiar a chave .pem para a pasta raiz do Bastion Host e realizar a conexão SSH conforme explicada anteriormente.
