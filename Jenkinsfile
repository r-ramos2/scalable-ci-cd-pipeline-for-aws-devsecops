pipeline {
  agent any

  tools {
    jdk 'jdk17'
    nodejs 'node16'
  }

  environment {
    SCANNER_HOME      = tool 'sonar-scanner'
    DOCKER_CREDENTIAL = 'dockerhub-creds'                        // Jenkins creds ID for Docker Hub
    IMAGE_NAME        = 'mydockerhubuser/amazon:latest'           // replace mydockerhubuser with your Docker Hub username
  }

  options {
    ansiColor('xterm')
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {
    stage('Cleanup') {
      steps {
        cleanWs()
      }
    }

    stage('Checkout') {
      steps {
        git branch: 'main',                                        // or your default branch name
            url: 'https://github.com/my-org/my-repo.git'           // replace with your GitHub org/repo
      }
    }

    stage('Static Code Analysis') {
      parallel {
        stage('SonarQube') {
          steps {
            withSonarQubeEnv('sonar-server') {
              sh """
                $SCANNER_HOME/bin/sonar-scanner \
                  -Dsonar.projectKey=Amazon \
                  -Dsonar.projectName=Amazon
              """
            }
          }
        }
        stage('Dependency Check') {
          steps {
            dependencyCheck additionalArguments: '--scan . --disableYarnAudit --disableNodeAudit',
                             odcInstallation: 'DP-Check'
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build & Test') {
      steps {
        dir('app') {
          sh 'CI=true npm ci'
          // run tests non-interactively; fail pipeline on failing tests
          sh 'CI=true npm test -- --watchAll=false --reporters=default'
        }
      }
    }

    stage('Trivy FS Scan') {
      steps {
        sh 'trivy fs . --exit-code 1 --severity HIGH,CRITICAL > TRIVYFS.txt || true'
        archiveArtifacts artifacts: 'TRIVYFS.txt'
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          def img = docker.build(env.IMAGE_NAME, './app')
          docker.withRegistry('', env.DOCKER_CREDENTIAL) {
            img.push()
          }
        }
      }
    }

    stage('Trivy Image Scan') {
      steps {
        sh "trivy image ${env.IMAGE_NAME} --exit-code 1 --severity HIGH,CRITICAL > TRIVYIMAGE.txt || true"
        archiveArtifacts artifacts: 'TRIVYIMAGE.txt'
      }
    }

    stage('Deploy & Smoke Test') {
      steps {
        sh "docker rm -f amazon || true"
        // container listens on 80 inside image; map host 3000 to container 80
        sh "docker run -d --name amazon -p 3000:80 ${env.IMAGE_NAME}"
        sh 'sleep 10'
        sh 'curl -f http://localhost:3000 || exit 1'
      }
    }
  }

  post {
    success {
      echo 'Pipeline succeeded!'
    }
    failure {
      mail to: 'team@example.com',
           subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
           body: "Please check Jenkins for details: ${env.BUILD_URL}"
    }
    always {
      cleanWs()
    }
  }
}
