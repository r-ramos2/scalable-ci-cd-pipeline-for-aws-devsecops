pipeline {
  agent any

  tools {
    jdk 'jdk17'
    nodejs 'node16'
  }

  environment {
    SCANNER_HOME      = tool 'sonar-scanner'            // ensure this tool is configured in Jenkins Global Tools
    DOCKER_CREDENTIAL = 'dockerhub-creds'               // Jenkins credentials ID for Docker Hub
    IMAGE_REPO        = 'mydockerhubuser/amazon'        // replace mydockerhubuser
  }

  options {
    ansiColor('xterm')
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {
    stage('Cleanup') {
      steps { cleanWs() }
    }

    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/my-org/my-repo.git' // update to your repo
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
        // Requires SonarQube webhook configured to Jenkins or polling setup
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build & Test') {
      steps {
        dir('app') {
          // Non-interactive tests; ensure CI=true so CRA behaves properly in CI
          sh 'CI=true npm ci --prefer-offline --no-audit'
          sh 'CI=true npm test -- --watchAll=false --reporters=default || (echo "Tests failed" && exit 1)'
        }
      }
    }

    stage('Trivy FS Scan') {
      steps {
        // Do not fail pipeline on scan result; archive report for visibility
        sh 'trivy fs . --exit-code 1 --severity HIGH,CRITICAL > TRIVYFS.txt || true'
        archiveArtifacts artifacts: 'TRIVYFS.txt'
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          def buildTag = "${env.BUILD_NUMBER ?: 'local'}"
          def imageTag = "${env.IMAGE_REPO}:${buildTag}"
          def imageLatest = "${env.IMAGE_REPO}:latest"
          // Build image
          def img = docker.build(imageTag, './app')
          docker.withRegistry('', env.DOCKER_CREDENTIAL) {
            img.push()
            img.push('latest')
          }
          // Expose tags as env for subsequent stages
          env.IMAGE_FULL = imageTag
        }
      }
    }

    stage('Trivy Image Scan') {
      steps {
        // Scan pushed image; archive report. Do not hard-fail here if you want to preserve artifacts.
        sh "trivy image ${env.IMAGE_FULL} --exit-code 1 --severity HIGH,CRITICAL > TRIVYIMAGE.txt || true"
        archiveArtifacts artifacts: 'TRIVYIMAGE.txt'
      }
    }

    stage('Deploy & Smoke Test') {
      steps {
        // Deploy on the Jenkins host (assumes Docker present and ports free)
        sh "docker rm -f amazon || true"
        sh "docker run -d --name amazon -p 3000:80 ${env.IMAGE_FULL}"
        sh 'sleep 10'
        sh 'curl -f http://localhost:3000 || (echo "Smoke test failed" && exit 1)'
      }
    }
  }

  post {
    success { echo 'Pipeline succeeded!' }
    failure {
      mail to: 'team@example.com',
           subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
           body: "Please check Jenkins for details: ${env.BUILD_URL}"
    }
    always { cleanWs() }
  }
}
