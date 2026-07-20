# terraform-ansible-monitor

Automated provisioning and configuration of an AWS EC2 web server with a monitoring stack, using Terraform, Ansible, and Jenkins.

Terraform provisions the AWS infrastructure (VPC, subnet, security group, EC2 instance) and generates an Ansible inventory. Ansible then configures the instance with Docker, Nginx, and a monitoring stack (Prometheus, Grafana, node_exporter). A Jenkins pipeline runs both stages end to end.

## Architecture

- **Terraform** (`terraform-aws-infra/`) creates:
  - A VPC with a public subnet and internet gateway
  - A security group allowing SSH, HTTP, Grafana (3000), Prometheus (9090), and a Jenkins webhook port (8081)
  - An EC2 instance (`t3.micro`)
  - An `ansible/hosts.ini` inventory file populated with the instance's public IP
- **Ansible** (`terraform-aws-infra/ansible/`) configures the EC2 instance:
  - Updates system packages
  - Installs and starts Docker
  - Runs Nginx (port 80)
  - Runs node_exporter (port 9100)
  - Runs Prometheus (port 9090)
  - Runs Grafana (port 3000)
- **Jenkins** (`Jenkinsfile`) automates the pipeline: `terraform init` → `terraform apply` → `ansible-playbook`

## Repository structure

```
.
├── Jenkinsfile
└── terraform-aws-infra/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── ansible/
        ├── ansible.cfg
        └── playbook.yml
```

## Prerequisites

- An AWS account with credentials configured (e.g. via `aws configure` or environment variables)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed
- An existing EC2 key pair in your target AWS region, with the private key (`.pem`) available locally
- Your public IP address (for restricting SSH/Grafana/Prometheus access)

## Setup

### 1. Configure Terraform variables

Copy the example variables file and fill in your own values:

```bash
cd terraform-aws-infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

| Variable     | Description                                            |
|--------------|----------------------------------------------------------|
| `aws_region` | AWS region to deploy into (default: `ap-south-1`)        |
| `ami_id`     | AMI ID to use for the EC2 instance                        |
| `key_name`   | Name of an existing EC2 key pair                          |
| `my_ip`      | Your public IP in CIDR form, e.g. `1.2.3.4/32`             |

### 2. Provision infrastructure with Terraform

```bash
terraform init
terraform apply
```

This creates the VPC, subnet, security group, and EC2 instance, and writes the instance's public IP into `ansible/hosts.ini`.

### 3. Configure the server with Ansible

Make sure your private key file matches `key_name` (e.g. `terraform-ansible-keypair.pem`) and is accessible, then run:

```bash
cd ansible
ansible-playbook -i hosts.ini playbook.yml
```

This installs Docker and starts Nginx, node_exporter, Prometheus, and Grafana as containers on the instance.

### 4. (Optional) Run via Jenkins

The included `Jenkinsfile` runs both steps automatically:

1. `terraform init` and `terraform apply` in `terraform-aws-infra/`
2. `ansible-playbook -i hosts.ini playbook.yml` in `terraform-aws-infra/ansible/`

Point a Jenkins pipeline job at this repository to use it.

## Accessing the services

Once provisioning completes, use the EC2 instance's public IP (available via `terraform output instance_public_ip`):

| Service     | URL                          |
|-------------|-------------------------------|
| Nginx       | `http://<public-ip>`           |
| Prometheus  | `http://<public-ip>:9090`      |
| Grafana     | `http://<public-ip>:3000`      |
| node_exporter metrics | `http://<public-ip>:9100/metrics` |

Grafana and Prometheus are restricted to your IP (`my_ip`) by the security group; Nginx (80) and the Jenkins webhook port (8081) are open to all.

## Notes

- Grafana's default login is `admin` / `admin` on first launch; you'll be prompted to change it.
- Prometheus is deployed without a custom `prometheus.yml`, so you'll need to add scrape configs (e.g. pointing at `node_exporter` on port 9100) to collect metrics.
- Destroy the infrastructure when you're done to avoid ongoing AWS charges:

```bash
cd terraform-aws-infra
terraform destroy
``ll`
