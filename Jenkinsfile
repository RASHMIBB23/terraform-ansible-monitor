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
                    sh 'ansible-playbook -i hosts.ini playbook.yml'
                }
            }
        }
    }
}
