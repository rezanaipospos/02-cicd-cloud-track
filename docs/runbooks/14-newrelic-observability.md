# Stage 07 — New Relic Observability + Argo Rollouts Metric-Gated Canary

Panduan ini mencakup:
1. Setup New Relic agent di aplikasi Go (instrumentasi lengkap)
2. Konfigurasi AnalysisTemplate Argo Rollouts dengan metric New Relic
3. Canary deployment 3-stage yang dikontrol metric otomatis

---

## Prasyarat

- Akun New Relic aktif (free tier cukup)
- Vault sudah dikonfigurasi (Story 6.1)
- Argo Rollouts terinstall di cluster (Story 5.3)

---

## 7a. Setup New Relic Account & Credentials

### 1. Buat New Relic API Keys

Di [New Relic One](https://one.newrelic.com) → **API keys**:

| Key Type | Digunakan Untuk | Nama di Vault |
|----------|----------------|---------------|
| **License key** (Ingest) | Go Agent → kirim data ke NR | `NR_LICENSE_KEY` |
| **User API key** | Argo Rollouts → query NRQL | `NR_API_KEY` |

Catat juga **Account ID** dari: Profile → API keys → Account ID.

### 2. Simpan ke Vault

```bash
# Pastikan VAULT_ADDR dan VAULT_TOKEN sudah di-export
# (lihat Stage 06 untuk cara akses Vault)

vault kv patch secret/backend-go/dev \
  NR_LICENSE_KEY="<YOUR_LICENSE_KEY>" \
  NR_API_KEY="<YOUR_USER_API_KEY>" \
  NR_ACCOUNT_ID="<YOUR_ACCOUNT_ID>"
```

### 3. Update ExternalSecret (sudah ada — trigger sync)

```bash
# Force refresh ExternalSecret agar Secret K8s terupdate
kubectl annotate externalsecret backend-go-newrelic-credentials \
  force-sync=$(date +%s) \
  -n backend-development
```

Verifikasi:

```bash
kubectl get secret newrelic-credentials -n backend-development
# → harus ada data.api-key dan data.account-id
```

---

## 7b. Instrumentasi Go Agent (sudah di-code)

File yang sudah dibuat:

| File | Isi |
|------|-----|
| `apps/backend-go/internal/telemetry/newrelic.go` | Singleton NR App — Init + Shutdown |
| `apps/backend-go/main.go` | Custom chi middleware: NR Transaction per request |
| `apps/backend-go/internal/handler/handler.go` | 5 jenis instrumentasi (lihat penjelasan di bawah) |

### Jenis Instrumentasi yang Diterapkan

#### 1. HTTP Transaction (otomatis via middleware)

```go
// main.go — middleware membuat Transaction per request
txn := app.StartTransaction("GET /api/v1/hello")
txn.SetWebRequestHTTP(r)
ww := txn.SetWebResponse(w)
ctx := newrelic.NewContext(r.Context(), txn)
```

#### 2. Function Segment

```go
// Span seluruh durasi fungsi bisnis
funcSeg := newrelic.StartSegment(txn, "handler.Hello/business-logic")
defer funcSeg.End()  // berakhir saat fungsi return
```

#### 3. Block of Code Segment

```go
// Span blok kode spesifik
{
    blkSeg := newrelic.StartSegment(txn, "handler.Hello/input-validation")
    _ = r.URL.Query().Get("lang")  // kode yang di-span
    blkSeg.End()
}
```

#### 4. Nested Segment (hirarki)

```go
// Parent segment
enrichSeg := newrelic.StartSegment(txn, "handler.Hello/enrichment")
{
    // Child segment di dalam parent
    fmtSeg := newrelic.StartSegment(txn, "handler.Hello/enrichment/format-message")
    greeting = fmt.Sprintf("%s 🚀", greeting)
    fmtSeg.End()
}
enrichSeg.End()
```

#### 5. Datastore Segment

```go
seg := newrelic.DatastoreSegment{
    StartTime:          txn.StartSegmentNow(),
    Product:            newrelic.DatastorePostgres,
    Collection:         "greetings",
    Operation:          "SELECT",
    ParameterizedQuery: "SELECT message FROM greetings WHERE lang = $1",
    DatabaseName:       "app_db",
    Host:               os.Getenv("DB_HOST"),
    PortPathOrID:       "5432",
}
defer seg.End()
```

#### 6. External Service Segment

```go
seg := &newrelic.ExternalSegment{
    StartTime: txn.StartSegmentNow(),
    URL:       "https://api.example.com/version",
    Procedure: http.MethodGet,
    Library:   "net/http",
}
defer seg.End()
```

### Env Vars yang Dibutuhkan di Pod

Tambahkan ke Vault secret `secret/backend-go/dev`, lalu ESO akan inject ke K8s Secret `backend-go-secrets`:

```
NEW_RELIC_LICENSE_KEY=<license_key>
NEW_RELIC_APP_NAME=backend-go
APP_ENV=development
```

---

## 7c. AnalysisTemplate New Relic

File: `05-gitops/applications/development/backend-go/canary/analysis-template-newrelic.yaml`

```
Metric          | Query NRQL                                              | Threshold
apdex-score     | SELECT average(apm.service.apdex) FROM Metric           | >= 0.9
error-rate      | SELECT percentage(count(*), WHERE httpResponseCode >=   | <= 5%
                | '500') FROM Transaction                                  |
```

Evaluasi: 2x per stage dengan interval 30 detik = total 1 menit assessment.

### Profile Secret yang Dibutuhkan Argo Rollouts

Argo Rollouts membaca NR credentials dari Secret bernama **`newrelic-credentials`** di namespace yang sama dengan Rollout:

```yaml
# Profile yang direferensikan di AnalysisTemplate:
# spec.provider.newRelic.profile: newrelic-credentials
#
# Secret harus berisi:
# data:
#   api-key: <base64 encoded NR User API Key>
#   account-id: <base64 encoded NR Account ID>
```

Secret dibuat otomatis oleh ESO dari Vault — lihat 7a.

---

## 7d. Canary Flow 3-Stage

```
Deploy canary image
        │
        ▼
Stage 1: 5% traffic
        │
    pause 1 menit  ──────────────────────────────────────
        │                                                │
        ▼                                                │
  AnalysisRun                                      GAGAL → ROLLBACK
  ├── apdex >= 0.9?                                      │
  └── error rate <= 5%?  ──── LULUS ──────────────────┐ │
                                                      │ │
                                                      ▼ │
                                              Stage 2: 50% traffic
                                                      │
                                                  pause 1 menit
                                                      │
                                                AnalysisRun
                                                ├── apdex >= 0.9?
                                                └── error rate <= 5%?
                                                      │
                                                      ▼
                                              Stage 3: 100% traffic
                                              (Full Promote — SELESAI)
```

### Monitor Progress

```bash
# Lihat status Rollout
kubectl argo rollouts get rollout backend-go-rollout -n backend-development -w

# Lihat AnalysisRun yang sedang berjalan
kubectl get analysisrun -n backend-development

# Lihat detail metric per run
kubectl describe analysisrun <nama-analysisrun> -n backend-development
```

### Manual Override (jika perlu)

```bash
# Promote paksa (skip analysis — emergency)
kubectl argo rollouts promote backend-go-rollout -n backend-development --full

# Abort rollout (rollback ke stable)
kubectl argo rollouts abort backend-go-rollout -n backend-development
```

---

## 7e. Verifikasi End-to-End

```bash
# 1. Pastikan pod backend-go running dan env var NR tersedia
kubectl exec -it deploy/backend-go-rollout -n backend-development -- env | grep NEW_RELIC

# 2. Akses endpoint beberapa kali untuk generate metric
curl https://<domain>/api/v1/hello
curl https://<domain>/api/v1/version

# 3. Cek di New Relic UI:
#    one.newrelic.com → APM → backend-go
#    Pastikan ada data: Transactions, Apdex, Error rate

# 4. Trigger deployment baru (mis: update image tag di rollout patch)
# CI akan update image tag → ArgoCD sync → Argo Rollouts mulai canary
kubectl argo rollouts get rollout backend-go-rollout -n backend-development -w
```

---

## Anti-Pattern yang Dihindari

| Anti-Pattern | Pattern yang Digunakan |
|-------------|------------------------|
| Manual gate (seseorang approve) | Metric-gated otomatis via AnalysisTemplate |
| Hardcode apdex threshold di kode | Threshold di AnalysisTemplate — bisa diubah tanpa rebuild |
| API key plaintext di repo | ESO fetch dari Vault |
| Agent init di setiap handler | Singleton di `telemetry.Init()` — init sekali di main |
| Panic saat NR tidak aktif | Graceful degradation — nil check sebelum semua NR call |
