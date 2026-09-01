# CI Pipeline — Jenkins + Shared Library + Webhook

**Tujuan:** Setup Pipeline jobs per environment dengan shared library,
trigger via GitHub webhook (Generic Webhook Trigger + HMAC).

---

## Prasyarat

- Jenkins running + plugin terinstall (Stage 02 + Stage 02b)
- GitHub repo app sudah ada dengan branch: `development`, `staging`, `production`
- Credentials di Jenkins sudah dikonfigurasi

---

## Model CI

- **3 Pipeline jobs** terpisah per app per environment (bukan Multibranch)
- **Trigger:** PR merged ke branch target → GitHub webhook → Jenkins
- **Setiap env build sendiri** (tidak build-once-promote)
- **Shared library** reusable untuk logika pipeline

| Job Name | Branch | Trigger |
|---|---|---|
| `backend-go-development` | `development` | PR merged ke development |
| `backend-go-staging` | `staging` | PR merged ke staging |
| `backend-go-production` | `production` | PR merged ke production |

---

## Step 1: Setup Credentials Jenkins

Manage Jenkins → Credentials → System → Global credentials → Add:

| Credential | Type | ID | Nilai |
|---|---|---|---|
| GitHub token | Username with password | `github-jenkins-token` | username: GitHub user, password: PAT |
| Slack token | Secret text | `slack-token` | Bot token `xoxb-...` |
| Webhook token dev | Secret text | `webhook-token-backend-go-dev` | `backend-go-development` |
| Webhook token staging | Secret text | `webhook-token-backend-go-staging` | `backend-go-staging` |
| Webhook token prod | Secret text | `webhook-token-backend-go-prod` | `backend-go-production` |

---

## Step 2: Setup Global Shared Library

Manage Jenkins → System → Global Trusted Pipeline Libraries → Add:

| Field | Nilai |
|---|---|
| Name | `course-shared-library` |
| Default version | `main` |
| Retriever | Modern SCM → Git |
| Project Repository | URL repo shared library kamu |
| Credentials | `github-jenkins-token` |

---

## Step 3: Buat Pipeline Jobs

**New Item → Pipeline → OK** untuk setiap job.

### Build Triggers → Generic Webhook Trigger:

| Field | Job development | Job staging | Job production |
|---|---|---|---|
| Token Credential | `webhook-token-backend-go-dev` | `webhook-token-backend-go-staging` | `webhook-token-backend-go-prod` |

**Post content parameters** (harus diisi di UI tiap job):

| Variable | Expression (JSONPath) |
|---|---|
| `payload` | `$` |
| `pr_num` | `$.pull_request.number` |
| `ACTION` | `$.action` |
| `pr_title` | `$.pull_request.title` |
| `pr_base_branch` | `$.pull_request.base.ref` |
| `pr_merged` | `$.pull_request.merged` |

**Optional filter:**

| Field | Job development | Job staging | Job production |
|---|---|---|---|
| Expression | `^closed true development$` | `^closed true staging$` | `^closed true production$` |
| Text | `$ACTION $pr_merged $pr_base_branch` | (sama) | (sama) |

### Pipeline section:

- **Definition:** Pipeline script
- **Script:**

```groovy
@Library('course-shared-library') _
containerPipeline()
```

> Atau pass parameter jika perlu:
> ```groovy
> @Library('course-shared-library') _
> containerPipeline(configPath: '.cicd/pipeline.yaml')
> ```

---

## Step 4: Setup GitHub Webhooks

```bash
HMAC_SECRET="GANTI_DENGAN_SECRET_YANG_SAMA_DI_JENKINS"
JENKINS_URL="https://jenkins.naipospos.cloud"
GITHUB_REPO="YOUR_ORG/backend-go"

# Development
gh api repos/${GITHUB_REPO}/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=${JENKINS_URL}/generic-webhook-trigger/invoke?token=backend-go-development" \
  --field "config[content_type]=json" \
  --field "config[secret]=${HMAC_SECRET}" \
  --field "events[]=pull_request"

# Staging
gh api repos/${GITHUB_REPO}/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=${JENKINS_URL}/generic-webhook-trigger/invoke?token=backend-go-staging" \
  --field "config[content_type]=json" \
  --field "config[secret]=${HMAC_SECRET}" \
  --field "events[]=pull_request"

# Production
gh api repos/${GITHUB_REPO}/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=${JENKINS_URL}/generic-webhook-trigger/invoke?token=backend-go-production" \
  --field "config[content_type]=json" \
  --field "config[secret]=${HMAC_SECRET}" \
  --field "events[]=pull_request"
```

---

## Step 5: Konfigurasi `.cicd/pipeline.yaml` di Repo App

```yaml
app_name: backend-go
language: go

test:
  command: "go test -v -cover ./..."

registry:
  region: asia-southeast1
  project_id: YOUR_PROJECT_ID
  repository: docker-images-repo

gitops:
  repo_url: github.com/YOUR_ORG/gitops-repo.git
  branch: main
  path: applications/development/backend-go/patch
  rollout_file: rollout.yaml

build:
  tool: docker
  branch: development

# Aktifkan Trivy Security Scan (Vulnerabilities, Secrets, IaC)
enable_security_scan: true

slack:
  channel: "#devops-course"

agent_label: "built-in"
```

---

## Verifikasi End-to-End

1. Buat PR ke branch `development` di repo app
2. Merge PR
3. Cek GitHub → Settings → Webhooks → Recent Deliveries → response 200 ✅
4. Cek Jenkins → job `backend-go-development` → build triggered ✅
5. Build stages: Checkout → Security Scan (Source) 🛡️ → Test → Build & Push (termasuk Security Scan Image) 🛡️ → Update GitOps ✅
6. Cek ArgoCD → `backend-go-dev` sync → Rollout update ✅
7. Cek Slack → notifikasi `SUCCESS` ✅

---

## Troubleshooting

```bash
# Webhook diterima tapi job tidak trigger
# → Cek Optional filter: $ACTION $pr_merged $pr_base_branch harus = "closed true development"

# readYaml error
# → Install plugin Pipeline Utility Steps

# Slack tidak kirim notif
# → Jangan pass tokenCredentialId di slackSend — biarkan global config yang handle

# checkout scm error
# → Pipeline script tidak support checkout scm, gunakan git step eksplisit
#   (sudah dihandle di containerPipeline.groovy)
```
