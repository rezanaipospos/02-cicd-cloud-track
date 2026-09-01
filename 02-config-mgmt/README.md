# 02 — Config Management (Ansible: Jenkins)

**Prereq:** 01-infra (VM Jenkins tersedia & reachable via IAP).

## Tujuan
Instalasi & konfigurasi Jenkins LTS di VM menggunakan Ansible yang **idempoten**. Jalankan dua kali = no change.

## Struktur

```
02-config-mgmt/
├── ansible.cfg                 # Konfigurasi Ansible (inventory, become, dll)
├── inventories/
│   └── dev/
│       └── hosts.yml           # Host VM Jenkins (koneksi IAP)
├── roles/
│   └── jenkins/
│       ├── defaults/main.yml   # Variabel default (port, plugins, java)
│       ├── tasks/main.yml      # Install Java, repo, Jenkins, plugins
│       └── handlers/main.yml   # Handler restart
└── playbooks/
    └── jenkins.yml             # Entry point
```

## Langkah

### 1. Isi inventory
Edit `inventories/dev/hosts.yml`:
- Ganti `<YOUR_PROJECT_ID>` dan `<YOUR_ZONE>` dengan project/zone-mu.
- `ansible_host` = nama VM dari output Terragrunt (default: `vm-jenkins-dev`).

### 2. Jalankan playbook
```bash
cd course-project/02-config-mgmt
ansible-playbook playbooks/jenkins.yml
```

### 3. Verifikasi
```bash
# Cek idempotency: run lagi, harus "changed=0"
ansible-playbook playbooks/jenkins.yml

# Akses Jenkins UI via IAP tunnel port-forwarding:
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone asia-southeast1-a -- -L 8080:localhost:8080
# Lalu buka http://localhost:8080 di browser
```

## Alternatif koneksi (pemula)
Jika ProxyCommand membingungkan:
```bash
# Terminal 1: buka tunnel
gcloud compute ssh vm-jenkins-dev --tunnel-through-iap --zone asia-southeast1-a -- -L 2222:localhost:22 -N

# Terminal 2: jalankan ansible ke localhost:2222
ansible-playbook playbooks/jenkins.yml -e "ansible_host=127.0.0.1 ansible_port=2222"
```

## Teardown
Tidak memprovisioning resource cloud (VM dihapus via stage 01). Jenkins bisa diuninstall via playbook terpisah jika diperlukan.

## Catatan biaya
Tidak ada resource tambahan (VM sudah ada dari stage 01). Jenkins gratis (open-source).
