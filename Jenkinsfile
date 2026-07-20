pipeline {
    agent any
    stages {
        stage('Terraform Init & Apply') {
            steps {
                dir('terraform-aws-infra') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
        stage('Run Ansible Playbook') {
            steps {
                dir('terraform-aws-infra/ansible') {
                    sh 'ansible-playbook -i hosts.ini playbook.yml'
                }
            }
        }
    }
}
