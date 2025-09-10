pipeline {
    agent { label 'build' }  // run on dedicated agent

    environment {
        ACME_SH_HOME = "${WORKSPACE}/.acme.sh"
        CERT_DIR     = "${WORKSPACE}/certs"
        ACME_SERVER  = "https://acme-staging-v02.api.letsencrypt.org/directory" // lets encrypt staging directory - avoid rate limiting
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prepare Workspace') {
            steps {
                sh '''
                  # install acme.sh to workspace-local home if not installed
                  mkdir -p $ACME_SH_HOME $CERT_DIR
                  if [ ! -x "$ACME_SH_HOME/acme.sh" ]; then
                    curl https://get.acme.sh | sh -s email=test@example.com --home $ACME_SH_HOME
                  fi
                '''
            }
        }

        stage('Provision HTTP-01 Challenges') {
            steps {
                sh '''
                  for row in $(jq -c '.[]' domains.json); do
                    domain=$(echo $row | jq -r .name)
                    alt_names=$(echo $row | jq -r '.alt_names | join(",")')

                    echo ">>> Provisioning challenge directories for $domain ($alt_names)"

                    # Create challenge dirs remotely
                    ansible -i ansible/inventory.ini all -m file \
                      -a \\"path=/var/www/html/.well-known/acme-challenge state=directory owner=www-data group=www-data mode=0755\\"
                  done
                '''
            }
        }

        stage('Issue Certificates') {
            steps {
                sh '''
                  for row in $(jq -c '.[]' domains.json); do
                    domain=$(echo $row | jq -r .name)
                    alt_names=$(echo $row | jq -r '.alt_names | join(",")')

                    echo ">>> Issuing certificate for $domain ($alt_names)"

                    $ACME_SH_HOME/acme.sh --issue \
                      --server $ACME_SERVER \
                      -d $domain \
                      $(for alt in $(echo $alt_names | tr ',' ' '); do echo -n "-d $alt "; done) \
                      --webroot /var/www/html \
                      --home $ACME_SH_HOME \
                      --debug \
                      --force

                    mkdir -p $CERT_DIR/$domain
                    $ACME_SH_HOME/acme.sh --install-cert -d $domain \
                      --key-file       $CERT_DIR/$domain/$domain.key \
                      --fullchain-file $CERT_DIR/$domain/$domain.crt \
                      --ca-file        $CERT_DIR/$domain/ca.cer \
                      --home $ACME_SH_HOME
                  done
                '''
            }
        }

        stage('Distribute Certificates') {
            steps {
                sh '''
                  # Run ansible from the agent; ansible must be installed on the agent
                  ansible-playbook -i ansible/inventory.ini ansible/deploy-certs.yml \
                    --extra-vars "cert_dir=$CERT_DIR"
                '''
            }
        }
    }

    post {
        always {
        archiveArtifacts artifacts: 'certs/**/*', allowEmptyArchive: true
        }
    }
}
