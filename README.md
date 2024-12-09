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
