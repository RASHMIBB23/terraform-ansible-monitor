output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/hosts.ini"
  content  = <<-EOT
    [webserver]
    ${aws_instance.web.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${var.key_name}.pem
  EOT
}

