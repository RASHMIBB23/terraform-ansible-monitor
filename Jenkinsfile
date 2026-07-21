pipeline {
    agent any
    stages {
        stage('Terraform Init & Apply') {
            steps {
                dir('terraform-aws-infra') {
                    withCredentials([file(credentialsId: 'terraform-tfvars', variable: 'TFVARS_FILE')]) {
                    sh 'cp $TFVARS_FILE terraform.tfvars'
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
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
