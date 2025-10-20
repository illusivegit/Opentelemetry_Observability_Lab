pipeline {
  agent { label 'docker-agent1' }
  options { timestamps() }

  environment {
    VM_USER    = 'deploy'
    VM_IP      = '192.168.122.250'
    DOCKER_CTX = 'vm-lab'
    PROJECT    = 'lab'
    VM_DIR     = '/home/deploy/lab/app'   // path on the VM
  }

  stages {
    stage('Checkout Code') {
      steps {
        git branch: 'main', url: 'https://github.com/illusivegit/Opentelemetry_Observability_Lab.git'
      }
    }

    stage('Sanity on agent') {
      steps {
        sh '''
          set -eu
          which ssh
          docker --version
          docker compose version
        '''
      }
    }

    stage('Ensure remote Docker context') {
      steps {
        sshagent(credentials: ['vm-ssh']) {
          sh '''
            set -eu
            ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} 'echo ok'
            docker context ls | grep -q "^${DOCKER_CTX} " || \
              docker context create ${DOCKER_CTX} --docker "host=ssh://${VM_USER}@${VM_IP}"
            docker --context ${DOCKER_CTX} info
          '''
        }
      }
    }

    // --- NEW: sync files that bind mounts need (simplest: mirror the whole repo)
    stage('Sync repo to VM') {
      steps {
        sshagent(credentials: ['vm-ssh']) {
          sh '''
            set -eu
            ssh ${VM_USER}@${VM_IP} "mkdir -p ${VM_DIR}"
            rsync -az --delete ./ ${VM_USER}@${VM_IP}:${VM_DIR}/
          '''
        }
      }
    }
    
    stage('Debug: verify compose paths') {
      steps {
        sshagent(credentials: ['vm-ssh']) {
          sh '''
            set -eu
            echo "== Local workspace PWD =="
            pwd
            echo "== Local workspace =="
            ls -la
            echo
            echo "== Remote VM dir =="
            ssh ${VM_USER}@${VM_IP} "ls -la ${VM_DIR} || true; \
              find ${VM_DIR} -maxdepth 2 -type f \\( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \\) -print"
          '''
        }
      }
    }

    stage('Compose up (remote via SSH)') {
      steps {
        sshagent(credentials: ['vm-ssh']) {
          sh '''
            set -eu
            export DOCKER_BUILDKIT=1
            ssh ${VM_USER}@${VM_IP} "
              cd ${VM_DIR} && \
              docker compose -p ${PROJECT} up -d --build && \
              docker compose -p ${PROJECT} ps
            "
          '''
        }
      }
    }


    stage('Smoke tests') {
      steps {
        sh '''
          set -eu
          curl -sf http://${VM_IP}:8080 >/dev/null || true
          curl -sf http://${VM_IP}:3000/login >/dev/null || true
          curl -sf http://${VM_IP}:9090/-/ready >/dev/null || true
        '''
      }
    }
  }

  post {
    failure {
      echo "Hint: tail remote logs → docker --context ${DOCKER_CTX} compose --project-directory ${VM_DIR} -p ${PROJECT} logs --no-color --tail=200"
    }
  }
}
