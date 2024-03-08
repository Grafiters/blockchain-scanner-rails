pipeline {
    agent any

    environment {
        IMAGE_FULL_NAME = 'devopsnusatech/oeypay-blockchain'
        DOCKERFILE = 'Dockerfile'
        DEPLOYMENT_PATH = '/root/oeypay'
        CONTAINER_NAMES = 'oeypay_deposit_1, oeypay_blockchain_1_1, oeypay_blockchain_2_1'
        CONTAINER_TO_RESTARTS = 'deposit, blockchain_1, blockchain_2'
        DEV_REMOTE_USER = 'root'
        DEV_SERVER_ADDRESS = '46.250.226.42'
        PROD_REMOTE_USER = 'prod_user'
        PROD_SERVER_ADDRESS = 'prod.server.address'
        MATTERMOST_ENDPOINT = 'https://team.nusatech.id/hooks/gdr9ikp64pdejqxb6zd6irfjrw'
        MATTERMOST_CHANNEL = 'oeypay'
        MATTERMOST_ICON = 'https://minio.nusatech.id/devops-asset/oeypay.png'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Gather Information') {
            steps {
                script {
                    env.GIT_COMMIT = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    env.GIT_AUTHOR = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
                    env.GIT_MESSAGE = sh(script: "git log -1 --pretty=format:'%s'", returnStdout: true).trim()
                }
            }
        }

        stage('Docker Build and Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-devops', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
                    script {
                        def imageExists = sh(script: "docker images -q ${IMAGE_FULL_NAME}", returnStdout: true).trim()
                        if (imageExists) {
                            echo "Removing existing image..."
                            sh "docker rmi -f ${IMAGE_FULL_NAME}"
                        }
                        echo "Building new image..."
                        sh "docker build -t ${IMAGE_FULL_NAME} -f ${DOCKERFILE} ."
                        echo "Pushing image to Docker Hub..."
                        sh "echo $DOCKERHUB_PASS | docker login -u $DOCKERHUB_USER --password-stdin"
                        sh "docker push ${IMAGE_FULL_NAME}"
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        input('Approve for Production Deployment?')
                        echo 'Deploying to Production Environment...'
                        deploy(PROD_REMOTE_USER, PROD_SERVER_ADDRESS)
                    } else {
                        echo 'Deploying to Development Environment...'
                        deploy(DEV_REMOTE_USER, DEV_SERVER_ADDRESS)
                    }
                }
            }
        }
        
        stage('Check Container Status') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        echo 'Checking Container Status in Production Environment...'
                        checkRemoteContainerStatus(PROD_REMOTE_USER, PROD_SERVER_ADDRESS)
                    } else {
                        echo 'Checking Container Status in Development Environment...'
                        checkRemoteContainerStatus(DEV_REMOTE_USER, DEV_SERVER_ADDRESS)
                    }
                }
            }
        }
    }

    post {
        success {
            mattermostSend(
                endpoint: "${env.MATTERMOST_ENDPOINT}", 
                channel: "${env.MATTERMOST_CHANNEL}", 
                color: '#00FF00',
                icon: "${env.MATTERMOST_ICON}",
                message: """
                    **Build Succeeded** :white_check_mark:
                    **Job**: `${env.JOB_NAME} [${env.BUILD_NUMBER}]`
                    **Branch**: `${env.BRANCH_NAME}`
                    **Environment**: `${env.BRANCH_NAME == 'main' ? 'Production' : 'Development'}`
                    **Commit**: `${env.GIT_COMMIT}`
                    **Author**: `${env.GIT_AUTHOR}`
                    **Message**: `${env.GIT_MESSAGE}`
                    [View Build](${env.BUILD_URL})
                    **Please check the Jenkins logs for more details.**
                """.trim()
            )
        }
        failure {
            mattermostSend(
                endpoint: "${env.MATTERMOST_ENDPOINT}", 
                channel: "${env.MATTERMOST_CHANNEL}", 
                color: '#FF0000',
                icon: "${env.MATTERMOST_ICON}",
                message: """
                    **Build Failed** :x:
                    **Job**: `${env.JOB_NAME} [${env.BUILD_NUMBER}]`
                    **Branch**: `${env.BRANCH_NAME}`
                    **Environment**: `${env.BRANCH_NAME == 'main' ? 'Production' : 'Development'}`
                    **Commit**: `${env.GIT_COMMIT}`
                    **Author**: `${env.GIT_AUTHOR}`
                    **Message**: `${env.GIT_MESSAGE}`
                    [View Build](${env.BUILD_URL})
                    **Please check the Jenkins logs for more details.**
                """.trim()
            )
        }
    }
}

def deploy(String remoteUser, String serverAddress) {
    def services = env.CONTAINER_TO_RESTARTS.split(',').collect { it.trim() }.join(' ')
    sshagent(credentials: ['ssh-dev']) {
        sh """
            ssh -o StrictHostKeyChecking=no ${remoteUser}@${serverAddress} '
                docker rmi -f ${env.IMAGE_FULL_NAME}
                cd ${env.DEPLOYMENT_PATH}
                docker-compose up -Vd ${services}
                docker image prune -f
            '
        """
    }
}

def checkRemoteContainerStatus(String remoteUser, String serverAddress) {
    env.CONTAINER_NAMES.split(',').collect { it.trim() }.each { containerName ->
        sshagent(credentials: ['ssh-dev']) {
            def result = sh(script: """
                ssh -o StrictHostKeyChecking=no ${remoteUser}@${serverAddress} '
                    docker container ls --filter "name=${containerName}" --format "{{.Status}}" | grep -oE "Up|Restarting|Down"
                '
            """, returnStdout: true).trim()

            if (result == "Up") {
                echo "${containerName} container is up and running on remote server"
            } else if (result == "Restarting") {
                error "${containerName} container is restarting on remote server, please check the logs and configuration"
            } else if (result == "Down") {
                error "${containerName} container is down on remote server, please check the logs and configuration"
            } else {
                error "${containerName} container not found or unexpected status on remote server, please check the logs and configuration"
            }
        }
    }
}
