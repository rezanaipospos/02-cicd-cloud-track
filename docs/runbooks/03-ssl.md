# SSL — Let's Encrypt Wildcard Certificate

**Tujuan:** Generate wildcard SSL cert `*.naipospos.cloud` menggunakan Let's Encrypt DNS challenge,
lalu apply cert yang sama sebagai Kubernetes Secret untuk ArgoCD dan backend-go-dev.

> Wildcard cert `*.naipospos.cloud` akan cover semua subdomain:
> `argocd.naipospos.cloud`, `backend-go-dev.naipospos.cloud`, `jenkins.naipospos.cloud`, dll.

---

## Prasyarat

- VM Jenkins running (Stage 01 applied)
- Domain `naipospos.cloud` sudah terdaftar dan DNS dapat dikelola
- Python3 + pip tersedia di VM Jenkins

---

## Step 1: Install Certbot di VM Jenkins

```bash
# SSH ke VM Jenkins via IAP
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a

# Install certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-dns-cloudflare

# Atau jika tidak pakai Cloudflare, install manual challenge:
sudo apt-get install -y certbot
```

---

## Step 2: Generate Wildcard Cert (DNS Challenge — Manual)

Gunakan DNS challenge karena wildcard tidak bisa diverifikasi via HTTP.

```bash
# Di dalam VM Jenkins
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "*.naipospos.cloud" \
  -d "naipospos.cloud" \
  --email admin@naipospos.cloud \
  --agree-tos \
  --no-eff-email
```

Certbot akan menampilkan instruksi seperti ini:
```
Please deploy a DNS TXT record under the name:
_acme-challenge.naipospos.cloud
with the following value: <TOKEN_VALUE>
```

**Tambahkan TXT record di DNS provider:**
1. Login ke DNS provider (Cloudflare, Google Domains, dll)
2. Tambah record: `_acme-challenge.naipospos.cloud` → `<TOKEN_VALUE>`
3. Tunggu propagasi DNS (1-5 menit)
4. Verifikasi: `dig TXT _acme-challenge.naipospos.cloud`
5. Tekan **Enter** di certbot

### Jika pakai Cloudflare (otomatis, tidak perlu manual):

```bash
# Buat API token Cloudflare (Zone:DNS:Edit)
cat > ~/.secrets/cloudflare.ini << 'EOF'
dns_cloudflare_api_token = YOUR_CLOUDFLARE_TOKEN
EOF
chmod 600 ~/.secrets/cloudflare.ini

# Generate cert otomatis
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d "*.naipospos.cloud" \
  -d "naipospos.cloud" \
  --email admin@naipospos.cloud \
  --agree-tos \
  --no-eff-email
```

---

## Step 3: Lokasi File Cert

Setelah berhasil, cert tersimpan di:

```bash
sudo ls -la /etc/letsencrypt/live/naipospos.cloud/
# fullchain.pem  → cert + intermediate chain
# privkey.pem    → private key
```

Verifikasi cert valid:
```bash
sudo openssl x509 -noout -subject -dates \
  -in /etc/letsencrypt/live/naipospos.cloud/fullchain.pem
# Subject: CN=*.naipospos.cloud
# NotAfter: 90 hari dari sekarang
```

---

## Step 4: Copy Cert ke Local Machine

Karena kubectl dijalankan dari local machine (bukan dari VM), copy cert ke local:

```bash
# Dari local machine — copy cert dari VM Jenkins
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a \
  -- "sudo cat /etc/letsencrypt/live/naipospos.cloud/fullchain.pem" > /tmp/fullchain.pem

gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone=asia-southeast1-a \
  -- "sudo cat /etc/letsencrypt/live/naipospos.cloud/privkey.pem" > /tmp/privkey.pem

# Verifikasi
openssl x509 -noout -subject -in /tmp/fullchain.pem
```

---

## Step 5: Apply SSL sebagai Kubernetes Secret (namespace argocd)

Secret ini digunakan oleh Envoy Gateway untuk TLS termination.
Satu secret, cover semua domain (wildcard).

```bash
# Dari local machine — pastikan kubectl sudah configured ke GKE
gcloud container clusters get-credentials gke-course-dev \
  --zone asia-southeast1-a \
  --project YOUR_PROJECT_ID

# Buat/update secret di namespace argocd
kubectl create secret tls ssl-cert-naipospos-cloud \
  --cert=/tmp/fullchain.pem \
  --key=/tmp/privkey.pem \
  --namespace=argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Verifikasi
kubectl get secret ssl-cert-naipospos-cloud -n argocd
kubectl describe secret ssl-cert-naipospos-cloud -n argocd
```

Satu secret ini cover semua domain karena wildcard `*.naipospos.cloud`:
- ✅ `argocd.naipospos.cloud`
- ✅ `backend-go-dev.naipospos.cloud`
- ✅ `jenkins.naipospos.cloud`
- ✅ domain lain `*.naipospos.cloud`

> **Tidak perlu buat secret terpisah per domain** — wildcard cert satu sudah cukup.

---

## Step 6: Label Namespace untuk Gateway Access

Namespace yang ingin expose domain via Gateway perlu label:

```bash
# ArgoCD (sudah ada, tapi pastikan ada label)
kubectl label namespace argocd shared-gateway-access=true --overwrite

# Backend development
kubectl label namespace backend-development shared-gateway-access=true --overwrite

# Verifikasi
kubectl get namespace -l shared-gateway-access=true
```

---

## Step 7: Verifikasi TLS

```bash
# Test argocd
curl -v https://argocd.naipospos.cloud 2>&1 | grep -E "CN=|subject:|SSL|TLS"

# Test backend-go-dev
curl -v https://backend-go-dev.naipospos.cloud 2>&1 | grep -E "CN=|subject:|SSL"

# Atau dengan openssl
echo | openssl s_client -connect argocd.naipospos.cloud:443 \
  -servername argocd.naipospos.cloud 2>/dev/null \
  | openssl x509 -noout -subject -dates
```

---

## Step 8: Setup Auto-Renewal

Cert Let's Encrypt expire setiap 90 hari. Setup cron untuk auto-renewal dan update secret:

```bash
# Di VM Jenkins — buat renewal script
sudo tee /usr/local/bin/renew-ssl.sh << 'EOF'
#!/bin/bash
# Renew cert
certbot renew --quiet

# Copy cert ke temp
cp /etc/letsencrypt/live/naipospos.cloud/fullchain.pem /tmp/fullchain.pem
cp /etc/letsencrypt/live/naipospos.cloud/privkey.pem /tmp/privkey.pem
chmod 644 /tmp/fullchain.pem /tmp/privkey.pem

echo "Cert renewed. Update Kubernetes secret manually via:"
echo "kubectl create secret tls ssl-cert-naipospos-cloud \\"
echo "  --cert=/tmp/fullchain.pem --key=/tmp/privkey.pem \\"
echo "  -n argocd --dry-run=client -o yaml | kubectl apply -f -"
EOF
sudo chmod +x /usr/local/bin/renew-ssl.sh

# Cron setiap bulan (hari 1 jam 02:00)
(sudo crontab -l 2>/dev/null; echo "0 2 1 * * /usr/local/bin/renew-ssl.sh") | sudo crontab -
```

> **Catatan:** Update Kubernetes Secret perlu dilakukan manual setelah renewal,
> karena kubectl memerlukan akses ke GKE cluster dari VM.

---

## Troubleshooting

```bash
# Cert tidak valid / mismatch
openssl s_client -connect argocd.naipospos.cloud:443 -servername argocd.naipospos.cloud

# Secret belum diupdate
kubectl get secret ssl-cert-naipospos-cloud -n argocd \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Gateway tidak menggunakan secret yang benar
kubectl describe gateway course-gateway -n argocd | grep -A5 tls

# DNS TXT record belum propagasi
dig TXT _acme-challenge.naipospos.cloud @8.8.8.8
```
