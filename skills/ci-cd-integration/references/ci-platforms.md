# CI Platform Pipeline Examples

Complete pipeline configurations for each supported CI platform. These examples use a Java app with docker-compose as the demo target — adapt the language (`--lang`), target/auth names, and app startup method to match the user's repo.

## GitHub Actions

### API scan with spec extraction and SARIF upload

```yaml
name: NightVision API Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  security-events: write

jobs:
  security-scan:
    runs-on: ubuntu-latest
    env:
      NIGHTVISION_TOKEN: ${{ secrets.NIGHTVISION_TOKEN }}
      NIGHTVISION_TARGET: my-api
      NIGHTVISION_AUTH: my-api
    steps:
      - uses: actions/checkout@v4

      - name: Install NightVision CLI
        run: |
          wget -c https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -O - | tar -xz
          sudo mv nightvision /usr/local/bin/

      - name: Extract API documentation from code
        run: |
          nightvision swagger extract . -t $NIGHTVISION_TARGET --lang java || true
          if [ ! -e openapi-spec.yml ]; then cp backup-openapi-spec.yml openapi-spec.yml; fi

      - name: Start the app
        run: docker compose up -d && sleep 15

      - name: Run scan and export SARIF
        run: |
          nightvision scan $NIGHTVISION_TARGET --auth $NIGHTVISION_AUTH > scan-results.txt
          nightvision export sarif -s "$(head -n 1 scan-results.txt)" --swagger-file openapi-spec.yml

      - name: Upload SARIF to GitHub Security
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

### API breaking change detection on PRs

```yaml
name: API Breaking Change Detection
on:
  pull_request:
    branches: [main]

jobs:
  api-diff:
    runs-on: ubuntu-latest
    env:
      NIGHTVISION_TOKEN: ${{ secrets.NIGHTVISION_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install NightVision CLI
        run: |
          wget -c https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -O - | tar -xz
          sudo mv nightvision /usr/local/bin/

      - name: Extract spec from PR branch
        run: nightvision swagger extract . -o new-spec.yml --lang java

      - name: Extract spec from base branch
        run: |
          git checkout ${{ github.event.pull_request.base.sha }}
          nightvision swagger extract . -o old-spec.yml --lang java
          git checkout ${{ github.event.pull_request.head.sha }}

      - name: Diff API specs
        run: nightvision swagger diff old-spec.yml new-spec.yml
```

## GitLab CI

GitLab's vulnerability dashboard requires its own DAST report format, not raw SARIF. The NightVision CLI emits it natively with `nightvision export gitlab`, so no external converter or separate SARIF-to-GitLab step is needed. Upload the result as a GitLab `dast` report; GitLab then deduplicates findings across pipelines on the report's stable per-finding fingerprint, so dismissals carry forward instead of reappearing as new.

Aggregating findings into the GitLab Vulnerability Report requires a GitLab Ultimate plan (or trial).

```yaml
stages:
  - scan

variables:
  NIGHTVISION_TARGET: my-api
  NIGHTVISION_APP: my-api
  NIGHTVISION_AUTH: my-api
  # Secure docker-in-docker: TLS on 2376, not the unauthenticated 2375 socket.
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_CERTDIR: "/certs"
  DOCKER_TLS_VERIFY: "1"
  DOCKER_CERT_PATH: "/certs/client"
  DOCKER_DRIVER: overlay2
  FF_NETWORK_PER_BUILD: "true"

# Run the full scan only on the default branch or a manual ("Run pipeline") trigger.
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_PIPELINE_SOURCE == "web"

dast_scan:
  stage: scan
  image: ubuntu:24.04
  services:
    - docker:dind
  before_script:
    - apt-get update && apt-get install -y wget ca-certificates docker.io docker-compose-v2
    - wget -c https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -O - | tar -xz
    - mv nightvision /usr/local/bin/
  script:
    # Extract the API spec; fall back to a committed backup but log loudly.
    - |
      if nightvision swagger extract ./ --lang spring -t "${NIGHTVISION_APP}"; then
        echo "Spec extracted from source."
      else
        echo "WARNING: swagger extract failed; using backup-openapi-spec.yml." >&2
        cp backup-openapi-spec.yml openapi-spec.yml
      fi
      # Guard on the artifact as well: a zero exit that wrote no spec (e.g. no
      # routes extracted) still falls back to the committed backup.
      [ -s openapi-spec.yml ] || cp backup-openapi-spec.yml openapi-spec.yml
    - docker compose up -d && sleep 15
    # Scan, then capture the scan id robustly (extract the UUID; fail if absent).
    - nightvision scan "${NIGHTVISION_TARGET}" --auth "${NIGHTVISION_AUTH}" | tee scan-results.txt
    - SCAN_ID=$(grep -oiE '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}' scan-results.txt | head -n1)
    - 'test -n "${SCAN_ID}" || { echo "ERROR no scan id found" >&2; exit 1; }'
    # Native GitLab DAST report (no external converter).
    - nightvision export gitlab -s "${SCAN_ID}" --swagger-file openapi-spec.yml -o gl-dast-report.json
  artifacts:
    reports:
      dast: gl-dast-report.json
    paths:
      - gl-dast-report.json
    expire_in: 30 days
```

## Azure DevOps

Azure DevOps uses `sarif-manager` to create Azure Boards work items with code traceability.

```yaml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  NIGHTVISION_TARGET: my-api
  NIGHTVISION_AUTH: my-api
  TARGET_URL: https://localhost:9000

stages:
- stage: Test
  jobs:
  - job: BuildAndTest
    steps:
    - checkout: self
      displayName: 'Clone Code'

    - script: wget -c https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -O - | tar -xz; sudo mv nightvision /usr/local/bin/
      displayName: 'Install NightVision'

    - script: nightvision swagger extract ./ -t $NIGHTVISION_TARGET --lang java
      displayName: 'Extract API Documentation from Code'
      env:
        NIGHTVISION_TOKEN: $(NIGHTVISION_TOKEN)

    - task: DockerCompose@1
      displayName: 'Start the app with Docker Compose'
      inputs:
        action: 'run services'
        detached: true
        buildImages: true

    - script: sleep 20; curl --retry 30 --retry-all-errors --retry-delay 1 --fail -k $TARGET_URL
      displayName: 'Wait for the app to start'

    - script: |
        nightvision scan $NIGHTVISION_TARGET --auth $NIGHTVISION_AUTH > scan-results.txt
        nightvision export sarif -s "$(head -n 1 scan-results.txt)" --swagger-file openapi-spec.yml
      displayName: 'Scan the API'
      env:
        NIGHTVISION_TOKEN: $(NIGHTVISION_TOKEN)

    - task: UsePythonVersion@0
      inputs:
        versionSpec: '3.11'
        addToPath: true

    - script: |
        python -m pip install --upgrade pip
        pip install sarif-manager
        sarif-manager azure create-work-items results.sarif \
          --write-logs \
          --org $(echo $(System.CollectionUri) | cut -d'/' -f4) \
          --project $(System.TeamProject) \
          --token $AZURE_DEVOPS_ACCESS_TOKEN
      displayName: 'Create Work Items in Azure DevOps'
      env:
        AZURE_DEVOPS_ACCESS_TOKEN: $(AZURE_DEVOPS_ACCESS_TOKEN)
```

**Scheduled scans** can be added with a cron trigger:
```yaml
schedules:
- cron: "0 0 * * *"
  displayName: Daily midnight run
  branches:
    include:
    - main
```

## Jenkins

Uses the Warnings Next Generation plugin (`recordIssues`) to display SARIF results.

```groovy
pipeline {
    agent any

    environment {
        NIGHTVISION_TOKEN = credentials('nightvision-token')
        NIGHTVISION_TARGET = 'my-api'
        NIGHTVISION_AUTH = 'my-api'
        TARGET_LANGUAGE = 'java'
    }

    stages {
        stage('Clone Code') {
            steps {
                checkout scm
            }
        }

        stage('Install NightVision') {
            steps {
                script {
                    sh 'wget -c https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -O - | tar -xz'
                }
            }
        }

        stage('Extract API Documentation from Code') {
            steps {
                script {
                    sh """
                    ./nightvision swagger extract . --target "${env.NIGHTVISION_TARGET}" --lang "${env.TARGET_LANGUAGE}" || true
                    if [ ! -e openapi-spec.yml ]; then
                        cp backup-openapi-spec.yml openapi-spec.yml
                    fi
                    """
                }
            }
        }

        stage('Start the App') {
            steps {
                script {
                    sh 'docker compose up -d; sleep 10'
                }
            }
        }

        stage('Scan the API') {
            steps {
                script {
                    sh """
                    ./nightvision scan "${env.NIGHTVISION_TARGET}" --auth "${env.NIGHTVISION_AUTH}" > scan-results.txt
                    ./nightvision export sarif -s \$(head -n 1 scan-results.txt) --swagger-file openapi-spec.yml
                    """
                }
            }
        }

        stage('Upload SARIF to Jenkins') {
            steps {
                script {
                    sh 'test -f results.sarif'
                    recordIssues tool: sarif(pattern: 'results.sarif')
                }
            }
        }
    }

    post {
        always {
            sh 'docker compose down'
        }
    }
}
```

## BitBucket Pipelines

### Private target (app started in pipeline)

```yaml
image: docker:stable

pipelines:
  default:
    - step:
        name: Scan App
        services:
          - docker
        script:
          - apk add --no-cache docker-compose curl tar
          - curl -L https://downloads.nightvision.net/binaries/latest/nightvision_latest_linux_amd64.tar.gz -q | tar -xz && mv nightvision /usr/local/bin/
          - nightvision swagger extract . -t $NIGHTVISION_TARGET --lang java || true
          - if [ ! -e openapi-spec.yml ]; then cp backup-openapi-spec.yml openapi-spec.yml; fi
          - docker-compose up -d && sleep 10
          - nightvision scan $NIGHTVISION_TARGET --auth $NIGHTVISION_AUTH > scan-results.txt
          - nightvision export sarif -s "$(head -n 1 scan-results.txt)" --swagger-file openapi-spec.yml
        max-time: 30
```

For public targets, the pipeline simplifies to just installing the CLI and running `nightvision scan <target>` (no Docker or spec extraction needed).

Store `NIGHTVISION_TOKEN` in BitBucket via Repository Settings > Repository Variables.

## JFrog Integration

Attaches DAST scan results and OpenAPI specs as evidence to Docker packages in JFrog Artifactory.

**Required secrets:** `ARTIFACTORY_ACCESS_TOKEN`, `JF_USER`, `PRIVATE_KEY`, `NIGHTVISION_TOKEN`

**Required variables:** `ARTIFACTORY_URL`, `BUILD_NAME`, `DOCKER_REPO`, `IMAGE_NAME`, `NIGHTVISION_PROVIDER_ID`

Key steps after building and scanning:

```yaml
- name: Upload DAST evidence to Docker package
  run: |
    jf evd create \
      --package-name ${{ vars.IMAGE_NAME }} \
      --package-version ${{ github.run_number }} \
      --package-repo-name ${{ vars.DOCKER_REPO }} \
      --key ${{ secrets.PRIVATE_KEY }} \
      --key-alias nightvision_evidence_key \
      --provider-id ${{ vars.NIGHTVISION_PROVIDER_ID }} \
      --predicate results.sarif \
      --predicate-type ${{ vars.NIGHTVISION_SCAN_RESULT_PREDICATE_TYPE }}

- name: Upload OpenAPI spec evidence
  run: |
    jf evd create \
      --package-name ${{ vars.IMAGE_NAME }} \
      --package-version ${{ github.run_number }} \
      --package-repo-name ${{ vars.DOCKER_REPO }} \
      --key ${{ secrets.PRIVATE_KEY }} \
      --key-alias nightvision_evidence_key \
      --provider-id ${{ vars.NIGHTVISION_PROVIDER_ID }} \
      --predicate openapi-spec.yml \
      --predicate-type ${{ vars.NIGHTVISION_OPENAPI_SPEC_PREDICATE_TYPE }}
```

Full reference: https://github.com/nvsecurity/jfrog-integration

