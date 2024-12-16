pipeline {
    agent {
        label 'build-agent'
    }

    parameters {
        activeChoice choiceType: 'PT_SINGLE_SELECT', description: 'Select deployment type', filterLength: 1, filterable: false, name: 'Deployment', randomName: 'choice-parameter-315670277436802', script: groovyScript(fallbackScript: [classpath: [], oldScript: '', sandbox: false, script: ''], script: [classpath: [], oldScript: '', sandbox: false, script: 'return [\'Frontend\', \'Backend\', \'Frontend + Backend\']'])
        
        string(
            name: 'FRONTEND_BRANCH',
            defaultValue: 'main',
            description: 'Enter Frontend Branch name (required if frontend is selected)'
        )
        string(
            name: 'BACKEND_BRANCH',
            defaultValue: 'main',
            description: 'Enter Backend Branch name (required if backend is selected)'
        )
    }

    environment {
        AWS_DEFAULT_REGION = {default_region}
        FRONTEND_REPO = {frontend_repo}
        BACKEND_REPO = {backend_repo}
        FRONTEND_DIR = {frontend_directory}
        BACKEND_DIR = {backend_directory}
        ECR_REGISTRY_URL = {ecr_url}
        NODE_ENV = {env}
    }

    stages {
        stage('Clean Workspace') {
            steps {
                deleteDir()
                sh 'docker builder prune -f'
                sh 'docker image prune -a -f'
            }
        }

        stage('Update Submodules') {
            steps {
                git branch: 'main', credentialsId: '{git_key}', url: '{git_url}'
                script {
                    sshagent(credentials: ['msm_git']) {
                        sh "git config -f .gitmodules submodule.${FRONTEND_DIR}/${FRONTEND_REPO}.branch ${params.FRONTEND_BRANCH}"
                        sh "git submodule update --init --recursive --remote ${FRONTEND_DIR}/${FRONTEND_REPO}"

                        sh "git config -f .gitmodules submodule.${BACKEND_DIR}/${BACKEND_REPO}.branch ${params.BACKEND_BRANCH}"
                        sh "git submodule update --init --recursive --remote ${BACKEND_DIR}/${BACKEND_REPO}"
                    }
                }
            }
        }

        stage('Build') {
            parallel {
                stage('Build Frontend') {
                    when {
                        expression { params.Deployment in ['Frontend', 'Frontend + Backend'] }
                    }
                    steps {
                        script {
                            withCredentials([file(credentialsId: '{env_file_creds}', variable: 'ENV_FILE')]) {
                                dir(FRONTEND_DIR) {
                                    sh "cp ${ENV_FILE} .env"
                                    sh "/usr/bin/bash frontend_vars.sh .env"
                                    sh "sed 's/server_name.*/server_name _;/' nginx-template.conf | awk '/^server {/ {i++} i>1 {next} 1' > nginx.conf"
                                    env.FRONTEND_COMMIT_HASH = sh(returnStdout: true, script: "cd msm-frontend && git rev-parse --short=7 HEAD").trim()
                                    sh "docker build --no-cache -t '${ECR_REGISTRY_URL}/${FRONTEND_REPO}:${FRONTEND_COMMIT_HASH}' ."
                                }
                            }
                        }
                    }
                }

                stage('Build Backend') {
                    when {
                        expression {
                            params.Deployment in ['Backend', 'Frontend + Backend']
                        }
                    }
                    steps {
                        script {
                            withCredentials([file(credentialsId: '{config_id}', variable: 'CONFIG_JSON')]) {
                                dir(BACKEND_DIR) {
                                    dir('{backend}') {
                                        sh "unzip -q -n pp-backend.zip"
                                    }
                                    sh "cp ${CONFIG_JSON} ${WORKSPACE}/${BACKEND_DIR}/{backend}/src/config/config.json"
                                    sh "sed 's/environment/${NODE_ENV}/g' entrypoint-template.sh > entrypoint.sh"
                                    env.BACKEND_COMMIT_HASH = sh(returnStdout: true, script: "cd {backend} && git rev-parse --short=7 HEAD").trim()
                                    sh "docker build --no-cache -t '${ECR_REGISTRY_URL}/${BACKEND_REPO}:${BACKEND_COMMIT_HASH}' ."
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Push Image') {
            when {
                expression {
                    currentBuild.resultIsBetterOrEqualTo('SUCCESS')
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: '{ecr_creds}', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    script {
                        sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_URL}"
                        if (params.Deployment in ['Frontend', 'Frontend + Backend']) {
                            sh "docker push '${ECR_REGISTRY_URL}/${FRONTEND_REPO}:${FRONTEND_COMMIT_HASH}'"
                        } else {
                            echo "Skipping frontend image"
                        }
                        if (params.Deployment in ['Backend', 'Frontend + Backend']) {
                            sh "docker push '${ECR_REGISTRY_URL}/${BACKEND_REPO}:${BACKEND_COMMIT_HASH}'"
                        } else {
                            echo "Skipping backend image"
                        }
                    }
                    stash includes: 'docker-compose-template.yaml', name: 'docker-compose-file'
                }
            }
        }

        stage('Deploy') {
            stages {
                stage('Deploy Frontend') {
                    when {
                        expression { params.Deployment in ['Frontend', 'Frontend + Backend'] }
                    }
                    agent { label '{deploy-agent}' }
                    steps {
                        unstash 'docker-compose-file'
                        script {
                            sh '''
                                export FRONTEND_PORT={frontend_port}
                                export FRONTEND_IMAGE="${ECR_REGISTRY_URL}/${FRONTEND_REPO}:${FRONTEND_COMMIT_HASH}"
                                sed -i '/backend_/,/msm_network/d' docker-compose-template.yaml
                                envsubst < docker-compose-template.yaml > docker-compose-frontend.yaml
                            '''
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: '{ecr_creds}', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                                sh '''#!/bin/bash
                                    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                                    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_URL}
                                    docker-compose -p {project} -f docker-compose-frontend.yaml up -d
                                '''
                            }
                        }
                    }
                }

                stage('Deploy Backend in all Regions') {
                    when {
                        expression { params.Deployment in ['Backend', 'Frontend + Backend'] }
                    }
                    stages {
                        stage("Deploying Backend in US") {
                            agent { label '{deploy-agent-us}' }
                            steps { deployBackend('US', '3000', 'backend-us') }
                        }
                        stage("Deploying Backend in CA") {
                            agent { label 'deploy-agent-ca' }
                            steps { deployBackend('CA', '3000', 'backend-ca') }
                        }
                        stage("Deploying Backend in AU") {
                            agent { label '{deploy-agent-au}' }
                            steps { deployBackend('AU', '3000', 'backend-au') }
                        }
                        stage("Deploying Backend in ZA") {
                            agent { label '{deploy-agent-za}' }
                            steps { deployBackend('ZA', '3000', 'backend-za') }
                        }
                        stage("Deploying Backend in EU") {
                            agent { label '{deploy-agent-eu}' }
                            steps { deployBackend('EU', '3000', 'backend-eu') }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment successful!'
        }

        failure {
            echo 'Deployment failed!'
        }
    }
}

def deployBackend(region, port, containerName) {
    script {
        unstash 'docker-compose-file'
        env.REGION_NAME = region
        env.CONTAINER_NAME_BACKEND = containerName
        env.selectedRegion = region.toLowerCase()
        env.PORT = port

        withCredentials([file(credentialsId: '{env_file_creds}', variable: 'ENV_FILE')]) {
            sh '''#!/bin/bash
                set -a
                source ${ENV_FILE}
                set +a
                export BACKEND_IMAGE="${ECR_REGISTRY_URL}/${BACKEND_REPO}:${BACKEND_COMMIT_HASH}"
                sed -i '/frontend:/,/msm_network/d' docker-compose-template.yaml
                envsubst < docker-compose-template.yaml > docker-compose-backend-${selectedRegion}.yaml
            '''
        }
    
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: '{ecr_creds}', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh '''#!/bin/bash
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_URL}
                docker-compose -p {project} -f docker-compose-backend-${selectedRegion}.yaml up -d
            '''
        }
    }
}
