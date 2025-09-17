pipeline {
    agent any
    
    parameters {
        string(name: 'TARGET_HOST', description: 'Target hostname for certificate deployment', trim: true)
        string(name: 'ACME_SERVER', defaultValue: 'https://acme-v02.api.letsencrypt.org/directory', description: 'ACME server endpoint')
    }
    
    environment {
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        CSR_DIR = '/local/mnt/workspace/acme/reqs'
        WORKSPACE_DIR = '/local/mnt/workspace/acme'
    }
    
    stages {
        stage('Validation') {
            steps {
                script {
                    if (!params.TARGET_HOST) {
                        error "TARGET_HOST parameter is required"
                    }
                    
                    // Check if CSR file exists
                    def csrFile = "${env.CSR_DIR}/${params.TARGET_HOST}.csr"
                    if (!fileExists(csrFile)) {
                        error "CSR file not found: ${csrFile}"
                    }
                }
            }
        }
        
        stage('Prepare Ansible Inventory') {
            steps {
                writeFile file: 'inventory.ini', text: """
[target]
${params.TARGET_HOST} ansible_ssh_pass="${env.SSH_PASSWORD}" ansible_ssh_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no'
"""
            }
        }
        
        stage('Deploy Certificate') {
            steps {
                withEnv(["ANSIBLE_HOST_KEY_CHECKING=False"]) {
                    ansiblePlaybook(
                        playbook: '${WORKSPACE_DIR}/acme-deploy.yml',
                        inventory: 'inventory.ini',
                        extras: "-e target_host=${params.TARGET_HOST} -e acme_server=${params.ACME_SERVER} -e csr_file=${CSR_DIR}/${params.TARGET_HOST}.csr"
                    )
                }
            }
        }
        
        stage('Verification') {
            steps {
                script {
                    sh """
                        ansible -i inventory.ini target -m command -a "openssl x509 -in /etc/ssl/certs/new-cert.cer -noout -subject" | grep "CN=${params.TARGET_HOST}"
                    """
                }
            }
        }
    }
    
    post {
        failure {
            echo "Certificate deployment failed for ${params.TARGET_HOST}"
            // Restore nginx backup if exists
            sh """
                ansible -i inventory.ini target -m shell -a "if [ -f /etc/nginx/conf.d/jenkins.conf.backup ]; then cp /etc/nginx/conf.d/jenkins.conf.backup /etc/nginx/conf.d/jenkins.conf && nginx -s reload; fi" || true
            """
        }
        success {
            echo "Certificate successfully deployed to ${params.TARGET_HOST}"
        }
    }
}