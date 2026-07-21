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
```


Nginx (80) and the Jenkins webhook port (8081) are open to all; SSH, Grafana, and Prometheus are restricted to `my_ip`.

## Verifying monitoring is working

1. Check Prometheus has picked up its targets: `http://<public-ip>:9090/targets` — both `node_exporter` and `prometheus` should show **UP**.
2. Run a live query in the Prometheus UI, e.g. `up` or `node_memory_MemAvailable_bytes`, to confirm data is flowing.
3. In Grafana (`admin`/`admin` on first login), add Prometheus as a data source at `http://localhost:9090`, then import dashboard ID `1860` ("Node Exporter Full") to visualize it.

Note: this stack currently monitors the **EC2 instance's host-level metrics only** (CPU, memory, disk, network) via node_exporter. It does not yet monitor application-level behavior (e.g. Nginx request rates or custom app metrics) — that would require adding another exporter (e.g. `nginx-prometheus-exporter`) and a matching scrape job in `prometheus.yml`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| SSH/Ansible times out connecting to the instance | Your public IP changed since `my_ip` was set — check with `curl ifconfig.me` and update `terraform.tfvars` |
| Ansible reports "no such identity: ...pem" | The private key isn't present in the Jenkins workspace — confirm the `ec2-ssh-key` credential is configured and wired into the pipeline |
| `terraform apply` fails with "No valid credential sources found" | AWS credentials aren't available to Jenkins — confirm `aws-access-key` / `aws-secret-key` credentials exist |
| `cp: cannot create regular file 'terraform.tfvars': Permission denied` | A stale, read-only `terraform.tfvars` is left over from a previous run — delete it, or rely on the pipeline's `rm -f terraform.tfvars` cleanup step |
| Prometheus targets page is empty | `prometheus.yml` isn't mounted into the container, or node_exporter/Prometheus aren't on the same Docker network (`network_mode: host`) |

## Cleanup

Destroy the infrastructure when you're done to avoid ongoing AWS charges:

```bash
cd terraform-aws-infra
terraform destroy




**Cause:**
The pipeline copies the SSH key from Jenkins credentials, then runs `chmod 400` on it to satisfy SSH's private-key permission requirements. On the *next* run, `cp` tries to overwrite that same 400-permission file — but overwriting requires write access to the existing file, not just the directory, so the copy fails.

**Fix:**
Remove the old key file before copying a fresh one, in the `Run Ansible Playbook` stage:

```groovy
sh 'rm -f terraform-ansible-keypair.pem'
sh 'cp $SSH_KEY_FILE terraform-ansible-keypair.pem'
sh 'chmod 400 terraform-ansible-keypair.pem'
```

This ensures every pipeline run starts with a clean key file regardless of permissions left by the previous run.```
