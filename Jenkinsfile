pipeline {
    agent any
    options {
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
    }
    triggers {
        cron 'H H/8 * * *'
    }

    stages {
        stage('Installing dependencies') {
            steps {
                echo 'installing NPM dependencies'
                sh '''
                npm i
                '''

                echo 'build jquery-ui'
                sh '''
                cd node_modules/jquery-ui
                npm i
                npm audit fix
                npx grunt concat requirejs uglify
                '''

                echo 'installing NPM dependencies'
                sh '''
                npx lix download
                '''
            }
        }

        stage('Download benchmark-runner cases') {
            steps {
                echo 'Copy Formatter detail pages'
                sh '''
                svn export https://github.com/HaxeBenchmarks/benchmark-runner/trunk/cases
                '''
            }
        }

        stage('Prepare site') {
            steps {
                echo 'Preparing site folder'
                sh '''
                mkdir -p site/js
                mkdir -p site/css
                '''
            }
        }

        stage('Copy files to site') {
            steps {
                echo 'Copy NPM files'
                sh '''
                cp node_modules/chart.js/dist/Chart.bundle.min.js site/js/Chart.min.js
                cp node_modules/chart.js/dist/Chart.min.css site/css/
                cp node_modules/jquery/dist/jquery.min.js site/js/
                cp node_modules/jquery-ui/dist/jquery-ui.min.js site/js/
                cp node_modules/jquery-ui/dist/jquery-ui.css site/css/
                cp -vau node_modules/jquery-ui/themes/base/images site/css/
                '''
            }
        }

        stage('Build benchmark.css') {
            steps {
                echo 'Building benchmark.cs'
                sh '''
                npx sass css/benchmark.scss site/css/benchmark.css
                '''
            }
        }

        stage('Build benchmark.js') {
            steps {
                echo 'Building benchmark.js'
                sh '''
                npx haxe buildPagesJS.hxml
                '''
            }
        }

        stage('Build Pages') {
            steps {
                echo 'Building benchmark.js'
                sh '''
                npx haxe buildDateilPages.hxml
                '''
            }
        }

        stage('Install to webserver') {
            steps {
                echo 'Install to webserver'
                sh '''
                rsync -rlu --delete site/* $BENCHMARKS_WEBROOT
                '''
            }
        }
    }
}