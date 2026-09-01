# Jenkins Plugins — Wajib Install

**Tujuan:** Install plugin Jenkins yang dibutuhkan untuk CI/CD pipeline.

---

## Plugin yang Wajib Diinstall

| Plugin | ID | Fungsi |
|--------|-----|--------|
| Generic Webhook Trigger | `generic-webhook-trigger` | Trigger job via GitHub webhook + HMAC + token routing |
| Slack Notification | `slack` | Kirim notifikasi build ke Slack channel |
| Lockable Resources | `lockable-resources` | `lock('gitops')` — cegah race condition saat update GitOps |
| Go | `golang` | Build Go application di pipeline |
| Pipeline Utility Steps | `pipeline-utility-steps` | `readYaml`, `writeYaml` untuk baca `.cicd/pipeline.yaml` |
| Docker Pipeline | `docker-workflow` | Docker build step di pipeline |
| Git | `git` | SCM checkout |
| Credentials Binding | `credentials-binding` | `withCredentials` step |

---

## Cara Install via UI

1. Manage Jenkins → **Plugins** → **Available plugins**
2. Search nama plugin → centang → klik **Install**
3. Centang **Restart Jenkins when installation is complete**

---

## Cara Install via CLI (dari VM Jenkins)

```bash
# SSH ke VM Jenkins
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a

# Ambil admin password
ADMIN_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "YOUR_ADMIN_PASSWORD")

JENKINS_URL="http://localhost:8080"

# Download jenkins-cli
wget -q -O /tmp/jenkins-cli.jar ${JENKINS_URL}/jnlpJars/jenkins-cli.jar

# Install semua plugin sekaligus
java -jar /tmp/jenkins-cli.jar \
  -s ${JENKINS_URL} \
  -auth admin:${ADMIN_PASS} \
  install-plugin \
  generic-webhook-trigger \
  slack \
  lockable-resources \
  golang \
  pipeline-utility-steps \
  docker-workflow \
  git \
  credentials-binding \
  -restart

# Tunggu Jenkins restart
sleep 30
echo "Plugin terinstall, Jenkins restarting..."
```

---

## Konfigurasi Post-Install

### 1. Slack Notification

Setelah plugin Slack terinstall:

1. Manage Jenkins → **System** → cari section **Slack**
2. Isi:
   - **Workspace**: nama workspace Slack (misal: `mtixateam`)
   - **Credential**: klik **Add** → Secret text → isi Bot Token `xoxb-...` → ID: `slack-token`
   - **Default channel**: `#deployments`
3. Klik **Test Connection** → harus muncul `Success`

> Token Slack: buka https://api.slack.com/apps → app kamu → OAuth → Bot User OAuth Token
> Scope minimal: `chat:write`, `chat:write.public`

### 2. Go Plugin

Setelah plugin Go terinstall:

1. Manage Jenkins → **Tools** → cari section **Go**
2. Klik **Add Go** → isi:
   - **Name**: `go-1.21` (nama ini dipakai di pipeline)
   - **Version**: pilih `1.21.x` atau versi terbaru
   - Centang **Install automatically**
3. Save

Pakai di Jenkinsfile:
```groovy
tools {
    go 'go-1.21'
}
```

### 3. Lockable Resources

Tidak perlu konfigurasi tambahan. Langsung pakai di pipeline:

```groovy
lock('gitops') {
    // operasi update GitOps di sini
    // hanya satu build yang bisa masuk sekaligus
}
```

> Resource `gitops` otomatis dibuat saat pertama kali `lock('gitops')` dipanggil.

### 4. Generic Webhook Trigger

Konfigurasi HMAC global:
1. Manage Jenkins → **System** → cari section **Generic Webhook Trigger**
2. Isi:
   - **Whitelist hosts**: (opsional, isi IP GitHub webhook)
   - **HMAC secret**: generate dengan `openssl rand -hex 20`
   - **HMAC header**: `X-Hub-Signature-256`
   - **HMAC algorithm**: `HmacSHA256`
3. Save

---

## Verifikasi Plugin Terinstall

```bash
# Via browser: Manage Jenkins → Plugins → Installed plugins
# Filter by nama plugin

# Via CLI
java -jar /tmp/jenkins-cli.jar \
  -s http://localhost:8080 \
  -auth admin:${ADMIN_PASS} \
  list-plugins | grep -E "slack|lockable|golang|generic-webhook|pipeline-utility"
```
