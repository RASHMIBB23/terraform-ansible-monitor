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
```
