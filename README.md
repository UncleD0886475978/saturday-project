# Terraform + Docker + Ansible — AWS EC2 Deployment

A fully automated infrastructure-as-code pipeline: Terraform provisions an EC2 instance, Ansible configures it, and Docker runs the containerized app.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazonaws&logoColor=white)

## Architecture

```mermaid
graph LR
    A[Terraform] -->|provisions| B[AWS EC2 t3.micro]
    C[Ansible] -->|configures| B
    C -->|installs & runs| D[Docker Container]
    D -->|serves app on port 80| E[Public Internet]
```

## What this does
- **Terraform** stands up a free-tier-eligible EC2 instance with the right security group (HTTP/SSH open)
- **Ansible** connects over SSH, installs Docker, and deploys the container
- **Docker** runs the app itself, reachable from any browser or device

## Getting started

```bash
# 1. Provision infrastructure
terraform init
terraform apply

# 2. Configure & deploy with Ansible
ansible-playbook -i inventory.ini deploy.yml

# 3. Tear down when done (avoid any lingering cost)
terraform destroy
```

## Tech stack
Terraform · Ansible · Docker · AWS EC2

## Author
Built by [Derick / SIM](https://github.com/UncleD0886475978)
