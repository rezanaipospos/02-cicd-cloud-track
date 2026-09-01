# Progressive Delivery (Argo Rollouts)

**Lokasi:** `05-gitops/infrastructure/progressive-delivery/`
**Prereq:** ArgoCD + app-of-apps berjalan (Story 5.1 & 5.2).

> Bagian ini berada di dalam `infrastructure/` karena Argo Rollouts adalah platform service
> yang di-manage ArgoCD via infrastructure Application — selaras dengan pola produksi.

## Struktur

```
progressive-delivery/
└── install/
    ├── README.md                               # versi + perintah verifikasi
    ├── kustomization.yaml
    └── argo-rollouts-controller-install.yaml   # Controller + CRDs + dashboard
```

## Per-App Rollout

Per-app rollout resources (Rollout, canary HPA) sekarang hidup di dalam folder application:

```
applications/{environment}/{app-name}/
├── canary/
│   ├── rollout.yaml    # kind: Rollout — canary strategy
│   └── hpa.yaml        # HPA targeting Rollout (bukan Deployment)
├── network/
│   └── http-route.yaml # Gateway API HTTPRoute + canary backendRef
└── ...
```

Pattern ini mengikuti example-project (flat common + env/app), dimana setiap app
mengontrol rollout strategy-nya sendiri per environment.

## Cara Install

ArgoCD infrastructure Application akan auto-sync `install/` ke cluster.
Tidak perlu apply manual — cukup pastikan ArgoCD infrastructure Application running.

## Cara Kerja Canary (Gateway API Traffic Routing)

1. CI update `images[].newTag` di `applications/{env}/backend-go/kustomization.yaml` → git push
2. ArgoCD sync → Rollout mulai canary steps
3. Traffic split via Gateway API HTTPRoute (weight-based, bukan replica-based)
4. Production: manual gate di step 50% → `kubectl argo rollouts promote`
5. Development/staging: auto-promote setelah pause duration

## Teardown

Hapus child Application dari ArgoCD, atau hapus rollout resources dari per-app kustomization.
