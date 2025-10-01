pipeline {
  agent any

  tools {
    jdk 'jdk17'
    nodejs 'node16'
  }

  environment {
    SCANNER_HOME      = tool 'sonar-scanner'
    DOCKER_CREDENTIAL = 'dockerhub-creds'
    // Configure via Jenkins environment variables or credentials
    DOCKERHUB_USER    = credentials('dockerhub-username') // Add this credential in Jenkins
    IMAGE_REPO        = "${DOCKERHUB_USER}/amazon"
    GIT_REPO_URL      = scm.userRemoteConfigs[0].url
    GIT_BRANCH        = scm.branches[0].name
  }

  options {
    ansiColor('xterm')
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  stages {
    stage('Cleanup') {
      steps {
        cleanWs()
      }
    }

    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse --short HEAD > .git/commit-id'
        script {
          env.GIT_COMMIT_SHORT = readFile('.git/commit-id').trim()
        }
      }
    }

    stage('Static Code Analysis') {
      parallel {
        stage('SonarQube Analysis') {
          steps {
            withSonarQubeEnv('sonar-server') {
              sh """
                ${SCANNER_HOME}/bin/sonar-scanner \
                  -Dsonar.projectKey=Amazon \
                  -Dsonar.projectName=Amazon \
                  -Dsonar.sources=./app/src \
                  -Dsonar.exclusions=**/node_modules/**,**/build/**
              """
            }
          }
        }
        
        stage('OWASP Dependency Check') {
          steps {
            dir('app') {
              dependencyCheck additionalArguments: '''
                --scan .
                --format HTML
                --format XML
                --disableYarnAudit
                --disableNodeAudit
              ''', odcInstallation: 'DP-Check'
              
              dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          script {
            // Wait for SonarQube webhook callback
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
              error "Pipeline aborted due to quality gate failure: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        dir('app') {
          sh 'npm ci --prefer-offline --no-audit'
        }
      }
    }

    stage('Run Tests') {
      steps {
        dir('app') {
          sh 'CI=true npm test -- --watchAll=false --coverage --reporters=default'
        }
      }
      post {
        always {
          // Archive test results and coverage if generated
          junit allowEmptyResults: true, testResults: 'app/coverage/junit.xml'
          publishHTML([
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'app/coverage/lcov-report',
            reportFiles: 'index.html',
            reportName: 'Code Coverage Report'
          ])
        }
      }
    }

    stage('Build Application') {
      steps {
        dir('app') {
          sh 'npm run build'
        }
      }
    }

    stage('Trivy Filesystem Scan') {
      steps {
        script {
          // Scan for critical vulnerabilities in source code and dependencies
          sh '''
            trivy fs . \
              --severity CRITICAL,HIGH \
              --format table \
              --output TRIVYFS.txt \
              --exit-code 0
          '''
        }
        archiveArtifacts artifacts: 'TRIVYFS.txt', allowEmptyArchive: true
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          def buildTag = "${env.BUILD_NUMBER}"
          def gitTag = "${env.GIT_COMMIT_SHORT}"
          def imageWithBuild = "${env.IMAGE_REPO}:${buildTag}"
          def imageWithGit = "${env.IMAGE_REPO}:${gitTag}"
          def imageLatest = "${env.IMAGE_REPO}:latest"
          
          // Build Docker image from app directory
          dir('app') {
            sh "docker build -t ${imageWithBuild} ."
            sh "docker tag ${imageWithBuild} ${imageWithGit}"
            sh "docker tag ${imageWithBuild} ${imageLatest}"
          }
          
          // Push to Docker Hub
          docker.withRegistry('https://index.docker.io/v1/', env.DOCKER_CREDENTIAL) {
            sh "docker push ${imageWithBuild}"
            sh "docker push ${imageWithGit}"
            sh "docker push ${imageLatest}"
          }
          
          // Store for next stages
          env.IMAGE_FULL = imageWithBuild
          env.IMAGE_LATEST = imageLatest
        }
      }
    }

    stage('Trivy Image Scan') {
      steps {
        script {
          // Scan the pushed Docker image for vulnerabilities
          sh """
            trivy image ${env.IMAGE_FULL} \
              --severity CRITICAL,HIGH \
              --format table \
              --output TRIVYIMAGE.txt \
              --exit-code 0
          """
        }
        archiveArtifacts artifacts: 'TRIVYIMAGE.txt', allowEmptyArchive: true
      }
    }

    stage('Deploy to Jenkins Host') {
      steps {
        script {
          // Stop and remove existing container if running
          sh 'docker rm -f amazon-app || true'
          
          // Deploy new container
          sh """
            docker run -d \
              --name amazon-app \
              --restart unless-stopped \
              -p 3000:80 \
              ${env.IMAGE_FULL}
          """
          
          // Wait for container to be healthy
          sh 'sleep 15'
        }
      }
    }

    stage('Smoke Test') {
      steps {
        script {
          // Verify the application is responding
          sh '''
            for i in {1..5}; do
              if curl -f http://localhost:3000; then
                echo "Smoke test passed!"
                exit 0
              fi
              echo "Attempt $i failed, retrying..."
              sleep 5
            done
            echo "Smoke test failed after 5 attempts"
            exit 1
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ Pipeline completed successfully!'
      echo "Application deployed at: http://localhost:3000"
      echo "Docker image: ${env.IMAGE_FULL}"
    }
    
    failure {
      echo '❌ Pipeline failed!'
      // Optional: Send email notification
      // mail to: 'team@example.com',
      //      subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      //      body: "Check Jenkins for details: ${env.BUILD_URL}"
    }
    
    always {
      // Clean up workspace but keep artifacts
      cleanWs(
        deleteDirs: true,
        patterns: [[pattern: 'TRIVY*.txt', type: 'EXCLUDE']]
      )
    }
  }
}
