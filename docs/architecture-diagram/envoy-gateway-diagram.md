┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           TRAFFIC FLOW                                              │
│                                                                                     │
│  Client Browser                                                                     │
│      │                                                                              │
│      │  HTTPS  backend-go-dev.naipospos.cloud                                      │
│      ▼                                                                              │
│  DNS A Record  ──────────────────────────────────────────────────────────►  GCP    │
│  (naipospos.cloud)                                                     Load Balancer│
│                                                                             IP      │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  namespace: argocd                                                                  │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────┐                       │
│  │  Gateway: course-gateway                                │                       │
│  │  ─────────────────────────────────────────────────────  │                       │
│  │  listeners:                                             │                       │
│  │    - name: http   port: 80                              │                       │
│  │    - name: https  port: 443                             │                       │
│  │      tls:                                               │                       │
│  │        certificateRefs:                                 │                       │
│  │          - name: ssl-cert-naipospos-cloud  ◄── Secret   │                       │
│  │  allowedRoutes:                                         │                       │
│  │    namespaces:                                          │                       │
│  │      matchLabels:                                       │                       │
│  │        shared-gateway-access: "true"  ◄─────────────── │──┐ HARUS ada label    │
│  └─────────────────────────────────────────────────────────┘  │ di namespace       │
│                          │  parentRef                          │                   │
└──────────────────────────┼─────────────────────────────────────┼───────────────────┘
                           │                                     │
         ┌─────────────────┼─────────────────────────────────────┤
         │                 │ parentRefs:                         │
         │  namespace: backend-development                       │
         │  label: shared-gateway-access: "true"  ◄─────────────┘
         │                 │
         │  ┌──────────────▼───────────────────────────────────────────────┐
         │  │  HTTPRoute: backend-go-route                                 │
         │  │  ─────────────────────────────────────────────────────────   │
         │  │  hostnames: ["backend-go-dev.naipospos.cloud"]               │
         │  │  parentRefs:                                                 │
         │  │    - name: course-gateway                                    │
         │  │      namespace: argocd     ◄─── referensi ke Gateway        │
         │  │      sectionName: https                                      │
         │  │  rules:                                                      │
         │  │    backendRefs:                                              │
         │  │      - name: backend-go-svc  ◄──────────────────────────┐   │
         │  │        port: 80              (stable traffic)            │   │
         │  │      - name: backend-go-svc-canary  ◄───────────────┐   │   │
         │  │        port: 80              (canary traffic)        │   │   │
         │  └──────────────────────────────────────────────────────┼───┼───┘
         │                                                          │   │
         │  ┌───────────────────────────────────────┐  ┌───────────┼───┼──────────────┐
         │  │  Service: backend-go-svc-canary        │  │  Service: backend-go-svc    │
         │  │  ───────────────────────────────────── │  │  ─────────────────────────  │
         │  │  spec:                                  │  │  spec:                      │
         │  │    selector:                            │  │    selector:                │
         │  │      app: backend-go  ◄──────────────── │  │      app: backend-go  ◄──  │
         │  │      rollouts-pod-template-hash: XXXX  │  │      rollouts-pod-template- │
         │  │  (diupdate Argo Rollouts otomatis)      │  │       hash: XXXX           │
         │  └────────────────────────────┬────────────┘  └──────────────┬─────────────┘
         │    CANARY selector            │  ◄─── Argo Rollouts          │ STABLE selector
         │    → pod canary (hash baru)   │       update selector        │ → pod stable
         │                               │       otomatis saat          │
         │                               │       canary berlangsung     │
         │  ┌────────────────────────────▼─────────────────────────────▼─────────────┐
         │  │  Rollout: backend-go-rollout                                            │
         │  │  ─────────────────────────────────────────────────────────────────────  │
         │  │  spec:                                                                  │
         │  │    selector:                                                            │
         │  │      matchLabels:                                                       │
         │  │        app: backend-go  ◄──────────────────────────────────────────────┤
         │  │    template:                                           HARUS SAMA       │
         │  │      metadata:                                        dengan selector   │
         │  │        labels:                                        di Service        │
         │  │          app: backend-go  ◄────────────────────────────────────────────┘
         │  │    strategy:                                                            │
         │  │      canary:                                                            │
         │  │        stableService: backend-go-svc  ◄── nama Service stable          │
         │  │        canaryService: backend-go-svc-canary  ◄── nama Service canary   │
         │  └─────────────────────────────────────────────────────────────────────────┘
         │                          manages
         │             ┌─────────────────────────────────┐
         │             │         ReplicaSet               │
         │             │  pod labels:                     │
         │             │    app: backend-go               │
         │             │    rollouts-pod-template-hash:   │
         │             │      7586c9c57b  (stable)        │
         │             │      XXXXXXXX   (canary)         │
         │             └────────────────┬────────────────┘
         │                              │
         │             ┌────────────────▼───────────────────────────────┐
         │             │  Pod: backend-go-rollout-7586c9c57b-xxxxx      │
         │             │  containerPort: 8080                           │
         │             │  /healthz  ◄── readinessProbe endpoint         │
         │             └────────────────────────────────────────────────┘
         └────────────────────────────────────────────────────────────────
