pipeline {
    agent any
    
    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }
    
    environment {
        IMAGE_NAME = "premd91/bankapp"
        TAG = "${params.DOCKER_TAG}"  // The image tag now comes from the parameter
        KUBE_NAMESPACE = 'webapps'
        SCANNER_HOME = tool 'sonar-scanner'
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/jdColonia/blue-green-deployment'
            }
        }

        stage('Compile') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn compile'
            }
        }

        stage('Test') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn test'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --format table -o fs.html .'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh "${SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=Multitier -Dsonar.projectName=Multitier -Dsonar.java.binaries=target"
                }
            }
        }

        stage('Quality Gate Check') {
            steps {
                timeout(time: 60, unit: 'SECONDS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Application') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn package -DskipTests=true'
            }
        }

        stage('Publish to Nexus') {
            tools {
                maven 'maven3'
            }
            steps {
                sh 'mvn deploy -DskipTests=true'
            }
        }

        stage('Docker Build & Tag') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${TAG} ."
            }
        }

        stage('Docker Image Scan') {
            steps {
                sh "trivy image --format table -o image-scan.html ${IMAGE_NAME}:${TAG}"
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([string(credentialsId: 'docker-hub', variable: 'DOCKER_HUB_PASS')]) {
                    sh "docker login -u premd91 -p ${DOCKER_HUB_PASS}"
                    sh "docker push ${IMAGE_NAME}:${TAG}"
                }
            }
        }

        stage('Deploy MySQL') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh 'kubectl apply -f k8s/mysql-deployment.yaml -n ${KUBE_NAMESPACE}'
                        sh 'kubectl apply -f k8s/mysql-service.yaml -n ${KUBE_NAMESPACE}'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl apply -f k8s/${params.DEPLOY_ENV}-deployment.yaml -n ${KUBE_NAMESPACE}"
                        sh 'kubectl apply -f k8s/service.yaml -n ${KUBE_NAMESPACE}'
                    }
                }
            }
        }

        stage('Switch Traffic') {
            when {
                expression { params.SWITCH_TRAFFIC == true }
            }
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl patch service bank-app-service -n ${KUBE_NAMESPACE} -p '{\"spec\":{\"selector\":{\"app\":\"${params.DEPLOY_ENV}\"}}}'"
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    withKubeConfig(credentialsId: 'k8-token') {
                        sh "kubectl get all -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'fs.html,image-scan.html', followSymlinks: false
        }
    }
}
