# 05 — GitOps: ArgoCD + Kustomize

**Prereq:** 04-gke (cluster GKE ready + kubectl configured).

## Tujuan
Deploy deklaratif pull-based: ArgoCD watch repo GitOps → auto-sync manifest ke cluster. Kustomize base-overlay untuk multi-env + shared common patches (DRY).

## Struktur
```
05-gitops/
├── bootstrap/
│   ├── install/             # ArgoCD install manifest (pinned version, as-code)
│   ├── project.yaml         # AppProject "course"
│   ├── root-app.yaml        # App-of-apps root Application
│   └── apps/                # Child Application definitions
│       ├── backend-go-dev.yaml
│       └── infrastructure.yaml
├── infrastructure/          # Platform services (argo-rollouts, envoy, vault — diisi epic berikutnya)
└── applications/
    ├── common/              # Shared base patches — DRY lintas-microservice (AD-7)
    │   └── patch/{deployment, service, hpa}
    └── backend-go/
        ├── base/            # App-specific deployment + service + refer common
        └── overlays/{development, staging, production}
```

## Promotion Pattern (AD-14 — build-once)
- CI (shared library) build image SEKALI → push tag SHA ke `overlays/development/kustomization.yaml`
- Promosi staging = copy tag yang sama ke `overlays/staging/` (bukan rebuild)
- Promosi production = copy tag yang sama ke `overlays/production/`
- ArgoCD auto-sync tiap overlay sebagai Application terpisah

## App-of-apps
`root-app.yaml` → sync `bootstrap/apps/` → tiap file = 1 child Application. Tambah app baru = tambah YAML di `apps/`, tanpa konfigurasi manual (AD-17).
