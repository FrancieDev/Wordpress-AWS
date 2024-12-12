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
      WORDPRESS_DB_NAME: /inserir nome da base de dados <Initial database name>/
    volumes:
      - /efs/wordpress:/var/www/html

volumes:
  wordpress:
  db:
EOF

sudo docker-compose up -d

```

O arquivo do script user data foi disponibilizado na íntegra na parte superior deste repositório para consultas. 

## 6) Key Pairs para conexão às instâncias EC2

Podemos nos conectar às instâncias EC2 através de nossa máquina local utilizando protocolo SSH para realizar tarefas de manutenção nas instâncias remotamente. Para isso, será preciso gerar um Key Pair, um arquivo para baixarmos e utilizar como chave-segredo para realizar a conexão remota. No dashboard da EC2, rolar na parte inferior esquerda da seção "NetWork and Security" até a opção "Key Pairs". Usaremos as seguintes configurações:

* Name: inserir um nome para a chave
* Key pair type: RSA
* Private key file format: .pem (é possível usar o formato .ppk, caso utilize o PuTTy para conexão remota)

Clique em "Create key pair" e será aberta uma janela para salvar o arquivo .pem em sua máquina local. Após salvar, copie a chave para a pasta raiz na sua máquina local, pois facilita posteriormente o reconhecimento da mesma quando utilizarmos o comando no terminal para a conexão SSH. Será preciso atribuir uma permissão ao arquivo .pem para conseguirmos estabelecer a conexão SSH, para isso, utilize o comando:

````
sudo chmod 400 nomedachave.pem
````


## 7) NAT Gateway

Como explicado no início, as máquinas EC2 serão criadas dentro das subnets privadas as quais ainda não possuem um ponto de acesso à internet. Para que as instâncias nas redes privadas consigam acessar a internet para baixar pacotes, mas que não possam ser acessíveis ao mundo exterior, precisamos criar um NAT gateway e conectá-lo à nossa VPC por meio das redes públicas. Para a criação do NAT gateway, acessamos o console da VPC e nos dirigimos até a lista de opções à esquerda. No submenu "Virtual Private Cloud" clicamos em "NAT gateways" e depois em "Create NAT gateway". Usamos os seguintes parâmetros:

* NAT Gateway settings
   * Name: inserir um nome (ex: NAT gateway_wordpress)
   * Subnet: escolher uma **subnet pública**
   * Connectivity type: Public
   * Elastic IP allocation ID: clicar em "Allocate Elastic IP"

Clicar em "Create NAT Gateway" e aguardar a confirmação da criação. Com o NAT Gateway criado, devemos agora associá-lo à tabela de rotas da rede privada. No console da VPC, clique em "Route Tables" e na lista das rotas, clicar na tabela de rotas privadas (route-private) e na próxima tela clicar em "Edit routes". Usamos os seguintes parâmetros para criar a rota da rede privada até o NAT Gateway:

* Destination: 0.0.0.0/0
* Target: NAT Gateway / (selecionar o NAT Gateway criado pelo pelo prefixo nat-)

Após clicar em "Save Changes" o NAT Gateway estará coretamente associado às redes privadas através das redes públicas e as instâncias EC2 terão acesso à internet para baixar e instalar pacotes.

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
  * Value: *fornecido pela Compass*
  * Resource types: marcar "Instances" e "Volumes"
  (3)
  * Key: Project
  * Value: *fornecido pela Compass*
  * Resource types: marcar "Instances" e "Volumes"

> Application and OS images
  * Ubuntu Noble 24.04 amd64 (Free tier eligible)

> Instance type
  *t2.micro (Free tier eligible)

> Key pair (login)
  * Key pair name: usar a key pair criada na etapa anterior

> Network settings (clicar em Edit)
  * VPC: usar a VPC criada
  * Subnet: usar uma subnet privada, preferencial na zona us-east-1a
  * Auto-assign public IP: Disable
  * Firewall (security groups)
    * Select existing security group: selecionar o security group criado para as EC2 privadas (private-instance)

> Advanced Details
  * User data: Neste campo vamos inserir o *script user data* para automatizar as tarefas de instalação do docker e Wordpress na inicialização da EC2. Podemos copiar e colar o script neste campo ou realizar upload do arquivo.

Clicar em "Launch Instance" e depois em "View all Instances". Aguardar o processo de criação e validação da instância, acompanhando pelo painel.

## 9) Launch Template

Launch Template é um recurso da AWS que permite reutilizarmos as configurações de criação de instâncias em execução. O template pode ser reutilizado, compartilhado e usado para iniciar novas instâncias, além de possuir diversas versões que ficam registradas em um histórico. Este recurso será importante também para a configuração do grupo Auto-Scaling que será explicado mais à frente. Existem duas formas de criamos o Launch Template: clicando no menu do EC2 "Launch Templates" ou diretamente pelas configurações da EC2. Usaremos a segunda opção, pois assim conseguimos copiar automaticamente todas as configurações da instância para o template.

Para isso, no dashboard EC2, clicamos em "Instances running", selecionamos e clicamos na instância EC2 que criamos na etapa anterior. No menu "Actions" e em "Images and templates" selecionamos "Create template from instance". Nesta tela, quase todas as configurações da EC2 criada foram aplicadas no template, bastando realizar alguns ajustes. Faremos as seguintes configurações:

* Launch template name and description
   * Launch template name - required: inserir um nome para o Launch Template
   * Template version description: inserir uma descrição para a versão do template (ex: version 1 ou v1)
   * Auto Scaling guidance: marcar "Provide guidance to help me set up a template that I can use with EC2 Auto Scaling"
* Network settings
   * Subnet: Selecionar "Don't include in launch template" (a subnet do template será atribuída pelo Auto-Scalling)
* Resource tags
   * Key (Name): private1
      * Resource types: Instances, Volumes
 * Key (CostCenter): *fornecido pela Compass*
      * Resource types: Instances, Volumes
 * Key (Name): *fornecido pela Compass*
      * Resource types: Instances, Volumes
 * Advanced details
    *  Shutdown behavior: Dont't include in launch template
    *  Stop - Hibernate behavior: Dont't include in launch template

Clicar em "Create Launch template" e o modelo já estará pronto para uso posteriormente pelo Auto-Scaling.

## 10) Bastion Host

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

Agora será possível acessar as instâncias privadas através do Bastion Host, bastando apenas copiar a chave .pem para a pasta /home/ubuntu da instância do Bastion Host e realizar a conexão SSH pelo sua máquina no temrinal. Como exemplo, utilizei o terminal do Ubuntu 22.04 em uma máquina local, acessando /home/<seu-nome-de-usuário> onde está localizada a chave *.pem*, bastando inserir o seguinte comando para acessar o Bastion Host:

```
ssh -i "key-name.pem" ubuntu@ecX-XX-XX-XXX-XXX.compute-1.amazonaws.com
```

Com o acesso ao Bastion Host bem-sucedido, podemos agora acessar as máquinas virtuais através do mesmo usando o comando de acesso fornecido na página "Connect to instance \ SSH client" em cada instância e realizar as tarefas necessárias. Contudo, será preciso ter privilégio de super usuário para acessar as EC2, caso contrário dará um erro de acesso negado, por isso usamos o comando ssh junto com o sudo dentro do Bastion Host:

```
sudo ssh -i "key-name.pem" ubuntu@ecX-XX-XX-XXX-XXX.compute-1.amazonaws.com
```

## 11) Load Balancer

Load Balancer é um recurso da AWS que distribui o tráfego de entrada das aplicações para diversos alvos de instâncias EC2 em zonas de disponibilidade distintas. Este recurso aumenta a tolerância à falhas da aplicações, detectando instâncias que estão indisponíveis e roteando o tráfego apenas para as instâncias disponíveis. Utilizamos o Classic Load Balancer para o projeto. No dashboard EC2, clicar em "Load Balancers", depois em "Create Load Balancers" e selecionar "Classic Load Balancer". Usaremos os seguintes parâmetros para criação:

* Basic configuration
   * Load balancer name: inserir nome para o load balancer
   * Scheme: internet-facing
* Network mapping
   * VPC: escolher a VPC do projeto
   * Availability zones: selecionar 2 zones e 2 subnets públicas
* Security group: selecionar o security group "Load Balancer"
* Listeners and routing
   * Listener HTTP:80
      * Listener protocol: HTTP
      * Listener port: 80
      * Instance protocol: HTTP
      * Instance port: 8080
* Health checks
   * Ping target
      * Ping protocol: HTTP
      * Ping port: 80
      * Ping port: /wp-admin/install.php
* Instances: clicar em "Add instances" e selecionar a(s) instância(s)

O restante das configurações permanece como padrão. Clicar em "Create load balancer" e aguardar para que o mesmo realize as verificações de registro da instância e os "health checks". Acompanhar pela aba "Target Instances".

## 12) Auto-Scaling Group

O Amazon EC2 Auto Scaling é um recuro para garantir que a arquitetura tenha o número correto de instâncias EC2 disponíveis para processar a carga da aplicação. Basicamente, os grupos de Auto Scaling são coleções de instâncias EC2. Podemos especificar o número mínimo de instâncias em cada grupo do Auto Scaling, e mesmo garante que o grupo nunca seja menor que esse tamanho. Também podemos especificar o número máximo de instâncias em cada grupo do Auto Scaling, garantindo que o grupo nunca seja maior que esse tamanho. No dashboard EC2, clicar em "Auto-Scaling Groups" e depois em "Create Auto Scaling Group". Usaremos as seguintes configurações:

STEP 1
* Choose template name
   * Auto scaling group name: inserir um nome para o auto-scaling
   * Launch template: selecionar o launch template criado na Etapa 9
   * Version: indicar a versão do template
STEP 2
* Network
   * VPC: escolher a VPC do projeto
   * Availability Zones and subnets: escolher as 2 redes privadas
   * Availability Zone distribution: Balanced best effor
STEP 3
* Load balancing
   * Attach to an existing load balancer
* Attach to an existing load balancer
   * Choose from Classic Load Balancers: Selecionar o Classic Load Balancer criado
* VPC Lattice integration options
   *  Select VPC Lattice service to attach: No VPC Lattice service
* Health checks
   * Marcar a opção "Turn on Elastic Load Balancing health checks"
* Configure group size and scaling
   * Group size
      * Desired capacity (especificar o número desejado de instâncias no lançamento do grupo): 2
   * Scaling
      * Min desired capacity: 2
      * Max desired capacity: 4
   * Automatic scaling: Target tracking scaling policy
   * Instance maintenance policy: No Policy
 
As outras configurações permanecem no padrão. Clicar em "Skip to Review" e em "Create Auto Scaling Group" 

## 13) Teste de Desempenho do Auto-Scaling

Para testar se o grupo Auto-scaling está funcionando corretamente, criando e encerrando instâncias com base na integridade das mesmas, podemos realizar um teste de desempenho utilizando um utilitário do próprio sistema da instância para estressar a CPU. Para isso, acessamos uma das instâncias EC2 via Bastion Host e instalamos o pacote de stress test com o seguinte comando:

```
sudo apt install stress
```

Agora, podemos iniciar um teste para estressar a CPU da instância usando os seguintes parâmetros:

```
stress --cpu 50 --vm-bytes 128M
```

É possível acompanhar o resultado do teste no painel do CloudWatch agent pela aba "Monitoring", tanto na instância como no Auto-Scaling. Acompanhando pelo CloudWatch agent da instância, observamos um incremento de 100% na atividade da CPU:

![Gráfico_incremento CPU](https://github.com/user-attachments/assets/297f92ca-04dc-43da-b765-b4797f91549a)

Após alguns segundos, é possível verificar que o AutoScaling iniciou a criação de uma nova instância em resposta ao teste de integridade:



## 14) Conclusões
Este projeto foi uma excelente oportunidade para praticar os conhecimentos adquiridos em AWS, Docker e Microsserviços, constituindo uma base sólida para a criação de novos projetos mais complexos. Agradeço a Compass UOL pela oportunidade da prática e orientação cuidadosa durante a execução do trabalho.  


