# Stage 02 — Config Management: Ansible Install Jenkins + HAProxy

**Tujuan:** install Jenkins + plugins + JCasC + HAProxy (Let's Encrypt TLS) dalam satu perintah Ansible.

## Prasyarat
- VM Jenkins sudah running (Stage 01 applied)
- Domain yang resolve ke IP publik VM (untuk Let's Encrypt)
  - Cek IP: `cd 01-infra/environments/dev/compute && terragrunt output instance_public_ip`
  - Set DNS A record: `jenkins.yourdomain.com → IP tersebut`

## Variabel yang WAJIB diisi

**1. Inventory** — `course-project/02-config-mgmt/inventories/dev/hosts.yml`:

| Variabel | Contoh | Penjelasan |
|----------|--------|------------|
| `<YOUR_PROJECT_ID>` | `my-devops-course` | Project GCP (untuk IAP tunnel) |
| `<YOUR_ZONE>` | `asia-southeast1-a` | Zone VM |

**2. HAProxy** — `course-project/02-config-mgmt/roles/haproxy/defaults/main.yml` (atau override di playbook):

| Variabel | Contoh | Penjelasan |
|----------|--------|------------|
| `haproxy_domain` | `jenkins.yourdomain.com` | Domain yang resolve ke IP publik VM |
| `haproxy_certbot_email` | `admin@yourdomain.com` | Email untuk notifikasi cert Let's Encrypt |

**3. Jenkins Credentials** — `course-project/02-config-mgmt/inventories/dev/group_vars/all/jenkins_credentials.yml`:

```bash
# Salin template lalu isi nilaimu
cd 02-config-mgmt/inventories/dev/group_vars/all
cp jenkins_credentials.yml.example jenkins_credentials.yml
# Edit jenkins_credentials.yml — isi semua credentials
```

### Panduan Generate GitHub Token (Fine-grained PAT)

> **PENTING:** Gunakan **Fine-grained Personal Access Token** (bukan Classic token).
> Fine-grained PAT membatasi akses hanya ke repo tertentu dan permission minimal (least privilege).

**Langkah:**

1. Buka: https://github.com/settings/tokens?type=beta (fine-grained)
2. Klik **"Generate new token"**
3. Isi:
   - **Token name:** `jenkins-ci-course` (deskriptif)
   - **Expiration:** 90 days (minimum yang masuk akal; set reminder untuk rotate)
   - **Resource owner:** pilih org/user yang punya repo
   - **Repository access:** pilih **"Only select repositories"** → pilih repo yang dibutuhkan Jenkins (app repo + gitops repo)

4. **Permissions (scope minimal untuk Jenkins CI):**

   | Category | Permission | Level | Kenapa dibutuhkan |
   |----------|------------|-------|-------------------|
   | Repository: Contents | Read and write | Wajib | Clone repo, push tag gitops overlay |
   | Repository: Metadata | Read | Wajib | Akses dasar repo |
   | Repository: Webhooks | Read and write | Wajib | Jenkins register/verify webhook |
   | Repository: Commit statuses | Read and write | Wajib | Jenkins report build status ke PR |
   | Repository: Pull requests | Read | Opsional | Jika pakai PR-based workflow |

   **JANGAN beri scope lain** (admin, delete, dll) — least privilege.

5. Klik **"Generate token"** → salin `github_XXXXX` → simpan langsung ke `jenkins_credentials.yml`

**Security best practices:**
- Jangan pakai Classic token (scope terlalu luas: `repo` = akses SEMUA repo)
- Set expiration maksimal 90 hari → rotate sebelum expire
- Jangan share token antar service (buat token terpisah per use-case)
- Jika token bocor: revoke langsung di https://github.com/settings/tokens

### Generate Webhook Secret

```bash
# Generate random webhook secret (HMAC-SHA256)
openssl rand -hex 20
# Output: abc123def456... → simpan di jenkins_github_webhook_secret
```

Jenkins akan verifikasi setiap webhook payload dari GitHub pakai secret ini.
Jika HMAC signature tidak cocok → reject (cegah spoofed webhook).

### Panduan Generate Slack Bot Token (untuk notifikasi Jenkins)

> **Opsional** — kosongi jika belum pakai Slack. Notifikasi build bisa diaktifkan nanti.

**Langkah:**

1. Buka: https://api.slack.com/apps → klik **"Create New App"**
2. Pilih **"From scratch"** → isi:
   - **App Name:** `Jenkins CI Bot`
   - **Workspace:** pilih workspace kamu
3. Di sidebar kiri, klik **"OAuth & Permissions"**
4. Scroll ke **"Scopes" → "Bot Token Scopes"** → tambahkan:

   | Scope | Kenapa dibutuhkan |
   |-------|-------------------|
   | `chat:write` | Kirim pesan notifikasi build ke channel |
   | `chat:write.public` | Kirim ke channel tanpa harus invite bot dulu |
   | `files:write` | (Opsional) Upload build log/artifact ke Slack |

   **JANGAN beri scope admin** — bot ini hanya perlu kirim pesan.

5. Scroll ke atas → klik **"Install to Workspace"** → authorize
6. Salin **"Bot User OAuth Token"** (`xoxb-xxxx-xxxx-xxxx`) → simpan ke `jenkins_slack_token`
7. **Workspace name** = nama workspace Slack kamu (bukan URL, bukan ID) → simpan ke `jenkins_slack_workspace`

**Invite bot ke channel:**
```
# Di Slack channel yang mau menerima notifikasi:
/invite @Jenkins CI Bot
```

**Security best practices:**
- Bot token hanya bisa kirim pesan (scope minimal) — tidak bisa baca history, manage channel, dll
- Token ini project-level (bukan user-level) — tidak terikat ke orang tertentu
- Jika bot tidak lagi dipakai: revoke di https://api.slack.com/apps → app settings → "Revoke All Tokens"
- Jangan simpan token di repo (sudah di-handle via `jenkins_credentials.yml` yang di-gitignore)

### Tabel Credentials Lengkap

| Variabel | Contoh | Penjelasan |
|----------|--------|------------|
| `jenkins_admin_user` | `admin` | Username admin Jenkins |
| `jenkins_admin_password` | `supersecret` | Password admin (ganti dari default!) |
| `jenkins_github_username` | `your-user` | GitHub user untuk checkout & push |
| `jenkins_github_token` | `ghp_xxxx` | GitHub Personal Access Token |
| `jenkins_github_webhook_secret` | `random-string` | Secret HMAC untuk webhook |
| `jenkins_github_org` | `your-org` | GitHub org/user untuk seed job |
| `jenkins_slack_token` | `xoxb-xxxx` | Slack bot token (kosongi jika belum pakai) |
| `jenkins_slack_workspace` | `your-ws` | Nama workspace Slack |
| `jenkins_shared_library_repo` | `https://github.com/...` | URL repo shared library |
| `jenkins_url` | `https://jenkins.yourdomain.com/` | URL Jenkins (untuk webhook callback) |

> **Opsional: encrypt pakai ansible-vault** untuk keamanan lebih:
> ```bash
> ansible-vault encrypt jenkins_credentials.yml
> # Saat jalankan playbook, tambah: --ask-vault-pass
> ```

## Langkah

```bash
cd course-project/02-config-mgmt

# 1. Edit inventory (ganti placeholder project_id + zone)
# File: inventories/dev/hosts.yml

# 2. Isi credentials Jenkins (salin template, isi nilai)
cd inventories/dev/group_vars/all
cp jenkins_credentials.yml.example jenkins_credentials.yml
# Edit jenkins_credentials.yml

# 3. (Opsional) Edit HAProxy domain
# File: roles/haproxy/defaults/main.yml

# 4. Jalankan playbook (install Jenkins saja — konfigurasi manual via UI)
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook playbooks/jenkins.yml --ask-vault-pass

# 5. Verifikasi idempotency (harus changed=0)
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook playbooks/jenkins.yml --ask-vault-pass
```

### Konfigurasi Manual Jenkins via UI

Setelah playbook selesai, buka Jenkins di browser dan konfigurasi secara manual:

**Step 1: Initial Setup Wizard**

1. Buka `http://VM_PUBLIC_IP:8080` atau `https://jenkins.yourdomain.com/` (jika HAProxy sudah setup)
2. Ambil initial admin password:
   ```bash
   gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a -- \
     "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
   ```
3. Paste password di wizard
4. Pilih **"Install suggested plugins"** → tunggu selesai
5. Buat admin user (username + password yang kamu inginkan)
6. Set Jenkins URL: `https://jenkins.yourdomain.com/` (atau `http://VM_IP:8080/` jika belum ada domain)

**Step 2: Install Plugin Tambahan**

Manage Jenkins → Plugins → Available plugins → install:

| Plugin | Kenapa |
|--------|--------|
| Generic Webhook Trigger | Trigger job via webhook + HMAC verification + branch filter |
| Slack Notification | Kirim notifikasi build ke Slack |
| Pipeline Utility Steps | `readYaml`, `writeYaml` untuk config-as-data |
| Role-based Authorization Strategy | RBAC per-job pattern (opsional, untuk production) |
| Lockable Resources | `lock('gitops')` di pipeline — cegah race condition push |
| Docker Pipeline | Docker build step di pipeline |
| Git | SCM checkout di Pipeline |

Restart Jenkins setelah install.

**Step 3: Setup Credentials**

Manage Jenkins → Credentials → System → Global credentials → Add:

| Credential | Type | ID | Nilai |
|---|---|---|---|
| GitHub token | Username with password | `github-jenkins-token` | username: GitHub user, password: Fine-grained PAT |
| Slack token | Secret text | `slack-token` | Bot token `xoxb-...` |
| Webhook secret | Secret text | `github-webhook-secret` | Random string dari `openssl rand -hex 20` |

**Step 4: Setup Global Shared Library**

Manage Jenkins → System → Global Trusted Pipeline Libraries → Add:

| Field | Nilai |
|---|---|
| Name | `course-shared-library` |
| Default version | `main` |
| Retriever | Modern SCM → Git |
| Project Repository | URL repo shared library kamu |
| Credentials | `github-jenkins-token` |

**Step 5: Buat Pipeline Jobs (3 job terpisah per environment)**

> **Catatan:** Kita pakai Pipeline job biasa (bukan Multibranch Pipeline). Setiap environment = 1 job terpisah.

Buat 3 job Pipeline — satu per environment:

| Job Name | Branch target | Trigger |
|---|---|---|
| `backend-go-development` | `*/development` | PR merged ke development |
| `backend-go-staging` | `*/staging` | PR merged ke staging |
| `backend-go-production` | `*/production` | PR merged ke production |

**Untuk setiap job — New Item → Pipeline → OK:**

1. **General:**
   - Description: `CI/CD for backend-go ({environment})`

2. **Build Triggers → Generic Webhook Trigger:**
   - Token: kosongkan
   - Token Credential: pilih credential yang sesuai env (lihat Step 6B)
   - Post content parameters:
     | Variable | Expression | JSONPath |
     |---|---|---|
     | `ref` | `$.ref` | ✓ |
     | `pr_number` | `$.pull_request.number` | ✓ |
     | `pr_merged` | `$.pull_request.merged` | ✓ |
   - Optional filter:
     | Field | Value (ganti per job) |
     |---|---|
     | Expression | `$ref $pr_merged` |
     | Text | `refs/heads/development true` |

3. **Pipeline:**
   - Definition: **Pipeline script from SCM**
   - SCM: Git
   - Repository URL: `https://github.com/YOUR_ORG/devops-backend-go.git`
   - Credentials: `github-jenkins-token`
   - Branch Specifier: `*/development` (ganti per job: staging/production)
   - Script Path: `Jenkinsfile`

4. Save → ulangi untuk staging dan production (ganti branch + token + filter text)

**Step 6: Setup GitHub Webhook (Token + HMAC — secure)**

> **Keamanan:** Token di URL untuk routing (job mana), HMAC untuk verify payload integrity. Tidak ada password/credentials di URL.

**A. Setup HMAC di Jenkins (global — 1x saja):**

1. Manage Jenkins → System → cari section **"Generic Webhook Trigger"**
2. Isi:
   | Field | Value |
   |---|---|
   | HMAC secret | `<random-secret>` — generate: `openssl rand -hex 20` |
   | HMAC header | `X-Hub-Signature-256` |
   | HMAC algorithm | `HmacSHA256` |
3. Save

**B. Setup Token Credential di Jenkins (per job):**

Manage Jenkins → Credentials → System → Global → Add Credentials:

| Credential ID | Type | Value |
|---|---|---|
| `webhook-token-backend-go-dev` | Secret text | `backend-go-development` |
| `webhook-token-backend-go-staging` | Secret text | `backend-go-staging` |
| `webhook-token-backend-go-prod` | Secret text | `backend-go-production` |

**C. Di setiap Pipeline job (Build Triggers → Generic Webhook Trigger):**

| Field | Job development | Job staging | Job production |
|---|---|---|---|
| Token | kosongkan | kosongkan | kosongkan |
| Token Credential | `webhook-token-backend-go-dev` | `webhook-token-backend-go-staging` | `webhook-token-backend-go-prod` |

Optional filter (agar hanya merged PR yang trigger):

| Field | Value |
|---|---|
| Expression | `$ref $pr_merged` |
| Text | `refs/heads/development true` (ganti per job) |

Post content parameters (extract data dari GitHub payload):

| Variable | Expression (JSONPath) |
|---|---|
| `ref` | `$.ref` |
| `pr_merged` | `$.pull_request.merged` |
| `pr_number` | `$.pull_request.number` |

**D. Setup GitHub Webhooks (3 per repo — 1 per env):**

```bash
HMAC_SECRET="<same-secret-as-jenkins-global>"

# Development
gh api repos/YOUR_ORG/devops-backend-go/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=https://jenkins.yourdomain.com/generic-webhook-trigger/invoke?token=backend-go-development" \
  --field "config[content_type]=json" \
  --field "config[secret]=$HMAC_SECRET" \
  --field "events[]=pull_request"

# Staging
gh api repos/YOUR_ORG/devops-backend-go/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=https://jenkins.yourdomain.com/generic-webhook-trigger/invoke?token=backend-go-staging" \
  --field "config[content_type]=json" \
  --field "config[secret]=$HMAC_SECRET" \
  --field "events[]=pull_request"

# Production
gh api repos/YOUR_ORG/devops-backend-go/hooks --method POST \
  --field name=web \
  --field active=true \
  --field "config[url]=https://jenkins.yourdomain.com/generic-webhook-trigger/invoke?token=backend-go-production" \
  --field "config[content_type]=json" \
  --field "config[secret]=$HMAC_SECRET" \
  --field "events[]=pull_request"
```

**Cara kerja:**
```
GitHub (PR merged ke development)
  → POST https://jenkins.yourdomain.com/generic-webhook-trigger/invoke?token=backend-go-development
  → Header: X-Hub-Signature-256: sha256=<hmac-of-payload>
  → Jenkins:
      1. HMAC verify (global) → payload valid ✅
      2. Token match → route ke job backend-go-development ✅
      3. Optional filter: ref=refs/heads/development, pr_merged=true → match ✅
      4. Trigger build
```

**Security layers:**
- ✅ HMAC-SHA256 global — reject spoofed payload (tanpa valid secret tidak bisa trigger)
- ✅ Token per job — routing O(1), bukan scan semua job
- ✅ HTTPS — token di URL encrypted in transit
- ✅ GitHub IP firewall — hanya GitHub webhook IPs bisa reach Jenkins
- ✅ Optional filter — double-check branch + merged status

**Step 7: Verifikasi Webhook**

1. Merge PR ke branch `development` di GitHub
2. Cek GitHub → repo Settings → Webhooks → Recent Deliveries → response 200
3. Cek Jenkins → job `backend-go-development` → build baru triggered
4. Job staging/production → tidak trigger (token berbeda, hanya job dev yang di-hit)

## Verifikasi
```bash
# Jenkins UI reachable via HTTPS (Let's Encrypt cert valid)
curl -I https://jenkins.yourdomain.com/
# Harus 200 or 302 (redirect ke login)

# Cek TLS cert
echo | openssl s_client -connect jenkins.yourdomain.com:443 -servername jenkins.yourdomain.com 2>/dev/null | openssl x509 -noout -issuer -dates
# issuer harus "Let's Encrypt"

# SSH via IAP (tetap berfungsi)
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone asia-southeast1-a
```
