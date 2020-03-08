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
                npx grunt requirejs uglify
                '''

                echo 'installing NPM dependencies'
                sh '''
                npx lix download
                '''
            }
        }

        stage('Prepare site') {
            steps {
                echo 'Preparing site folder'
                sh '''
                mkdir -p site/js
                mkdir -p site/css

                for i in js css data; do \
                    mkdir -p site/alloc/$i \
                    mkdir -p site/formatter-io/$i \
                    mkdir -p site/formatter-noio/$i; \
                done
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

        stage('Copy files to site') {
            steps {
                echo 'Copy NPM files'
                sh '''
                cp node_modules/chart.js/dist/Chart.bundle.min.js site/js/Chart.min.js
                cp node_modules/chart.js/dist/Chart.min.css site/css/
                cp node_modules/jquery/dist/jquery.min.js site/js/
                cp node_modules/jquery-ui/dist/jquery-ui.min.js site/js/
                cp -vau node_modules/jquery-ui/themes site/css
                '''

                echo 'Create symlinks'
                sh '''
                (cd site/alloc/js; ln -sfn ../../js/* .)
                (cd site/alloc/css; ln -sfn ../../css/* .)

                (cd site/formatter-io/js; ln -sfn ../../js/* .)
                (cd site/formatter-io/css; ln -sfn ../../css/* .)

                (cd site/formatter-noio/js; ln -sfn ../../js/* .)
                (cd site/formatter-noio/css; ln -sfn ../../css/* .)
                '''
            }
        }

        stage('Link data to site') {
            steps {
                echo 'Link alloc data'
                sh '''
                cd site/alloc/data;
                ln -sfn /home/benchmarkdata/alloc-benchmark/Haxe-3/results.json archiveHaxe3.json
                ln -sfn /home/benchmarkdata/alloc-benchmark/Haxe-4/results.json archiveHaxe4.json
                ln -sfn /home/benchmarkdata/alloc-benchmark/Haxe-nightly/results.json archiveHaxeNightly.json
                '''

                echo 'Link formatter-io data'
                sh '''
                cd site/formatter-io/data;
                ln -sfn /home/benchmarkdata/formatter-benchmark/Haxe-3/results.json archiveHaxe3.json
                ln -sfn /home/benchmarkdata/formatter-benchmark/Haxe-4/results.json archiveHaxe4.json
                ln -sfn /home/benchmarkdata/formatter-benchmark/Haxe-nightly/results.json archiveHaxeNightly.json
                '''

                echo 'Link formatter-noio data'
                sh '''
                cd site/formatter-noio/data;
                ln -sfn /home/benchmarkdata/formatter-benchmark-noio/Haxe-3/results.json archiveHaxe3.json
                ln -sfn /home/benchmarkdata/formatter-benchmark-noio/Haxe-4/results.json archiveHaxe4.json
                ln -sfn /home/benchmarkdata/formatter-benchmark-noio/Haxe-nightly/results.json archiveHaxeNightly.json
                '''
            }
        }

        stage('Copy detail pages') {
            steps {
                echo 'Copy Formatter detail pages'
                sh '''
                mkdir -p formatter-bench
                cd formatter-bench
                svn export https://github.com/HaxeBenchmarks/formatter-benchmark/trunk/www
                cp www/index.html ../site/formatter-io
                cp www/indexNoIO.html ../site/formatter-noio/index.html
                rm -rf www
                '''

                echo 'Copy Alloc detail pages'
                sh '''
                mkdir -p alloc-bench
                cd alloc-bench
                svn export https://github.com/HaxeBenchmarks/alloc-benchmark/trunk/www
                cp www/index.html ../site/alloc
                rm -rf www
                '''
            }
        }
        stage('Install to webserver') {
            steps {
                echo 'Install to webserver'
                sh '''
                rsync -rlu --delete site/* /var/www/benchs
                '''
            }
        }
    }
}