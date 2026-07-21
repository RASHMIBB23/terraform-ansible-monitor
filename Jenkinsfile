pipeline {
    agent any
    stages {
        stage('Terraform Init & Apply') {
            steps {
                dir('terraform-aws-infra') {
                    withCredentials([
                        file(credentialsId: 'terraform-tfvars', variable: 'TFVARS_FILE'),
                        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh 'rm -f terraform.tfvars'
                        sh 'cp $TFVARS_FILE terraform.tfvars'
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
        stage('Wait for instance to boot') {
            steps {
                sh 'sleep 45'
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                dir('terraform-aws-infra/ansible') {
                    withCredentials([file(credentialsId: 'ec2-ssh-key', variable: 'SSH_KEY_FILE')]) {
                        sh 'cp $SSH_KEY_FILE terraform-ansible-keypair.pem'
                        sh 'chmod 400 terraform-ansible-keypair.pem'
                        sh 'ansible-playbook -i hosts.ini playbook.yml'
                    }
                }
            }
        }
    }
}
