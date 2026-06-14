# Argo Rollouts Progressive Canary Demo

This repository demonstrates a GitOps-managed progressive canary deployment on
Amazon EKS. ArgoCD reconciles the production overlay, and Argo Rollouts replaces
a standard Kubernetes `Deployment` with a controlled rollout of the Argo
Rollouts demo application built from source and stored in Amazon ECR.

The initial version is `blue`. Changing the Kustomize image tag to `green`
starts a canary rollout across five replicas.

## What This Demo Proves

- Application configuration can live with the application under
  `deploy/overlays/prod`.
- ArgoCD can detect a committed image-tag change and synchronize it to EKS.
- Argo Rollouts can gradually replace blue pods with green pods.
- An AWS Application Load Balancer can expose the application through one
  Kubernetes `Service`.
- Rollout status and application traffic can be observed during the change.

This first phase intentionally uses basic Argo Rollouts canary behavior. It does
not configure ALB traffic routing, separate stable and canary services, or
metrics-driven rollback.

## Repository Layout

```text
deploy/
├── base/
│   ├── rollout.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── overlays/
    └── prod/
        ├── kustomization.yaml
        └── patch-rollout.yaml
scripts/
├── build-and-push-ecr.sh
├── get-alb-url.sh
├── watch-rollout.sh
├── generate-traffic.sh
└── promote-blue-to-green.sh
src/
├── Dockerfile
├── Makefile
├── main.go
└── application assets
```

The GitOps path for this application is:

```text
deploy/overlays/prod
```

## Prerequisites

- An EKS cluster
- ArgoCD
- Argo Rollouts and the `kubectl argo rollouts` plugin
- AWS Load Balancer Controller
- `kubectl` configured for the cluster
- `kustomize`
- AWS CLI profile `personal-ssg` authenticated to account `364641874932`
- Docker with Buildx
- Permission to push images to the `ibs-demo-apps` ECR repository
- A `rollouts-demo` namespace, or an ArgoCD Application configured with
  `CreateNamespace=true`

## Application Image

The application source under `src/` is based on the official
[`argoproj/rollouts-demo`](https://github.com/argoproj/rollouts-demo) project,
using upstream commit `f528fdd2189e877dfb8a2de21b6989853e8e8d26` as the
reference snapshot.

The production overlay maps the logical `rollouts-demo` image to:

```text
364641874932.dkr.ecr.ap-south-1.amazonaws.com/ibs-demo-apps
```

Build and push the initial blue and green images:

```bash
./scripts/build-and-push-ecr.sh
```

The script logs Docker into ECR, builds Linux/AMD64 images, and pushes:

```text
364641874932.dkr.ecr.ap-south-1.amazonaws.com/ibs-demo-apps:blue
364641874932.dkr.ecr.ap-south-1.amazonaws.com/ibs-demo-apps:green
```

Environment variables can override the defaults:

```bash
AWS_REGION=ap-south-1 \
AWS_PROFILE=personal-ssg \
ECR_REPOSITORY=364641874932.dkr.ecr.ap-south-1.amazonaws.com/ibs-demo-apps \
TARGET_PLATFORM=linux/amd64 \
./scripts/build-and-push-ecr.sh blue green
```

For the later rollback phase, build the intentionally unhealthy image with:

```bash
./scripts/build-and-push-ecr.sh bad-green
```

## How GitOps Deployment Works

An ApplicationSet should discover this repository and create an ArgoCD
Application whose source path is `deploy/overlays/prod`. The generated
Application should target the `rollouts-demo` namespace and may use this sync
option so the namespace is created automatically:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

ArgoCD continuously compares the Git revision with the cluster. After the
Kustomize image tag is committed and pushed, ArgoCD detects the changed rendered
`Rollout` and synchronizes it. Normal deployment does not require
`kubectl apply`.

EKS worker nodes authenticate to ECR through their node IAM role. No Kubernetes
image pull secret is required when the node role has normal ECR pull access.

## Canary Sequence

When the image changes from `blue` to `green`, Argo Rollouts creates green pods
and progresses through these steps:

1. 20% green, then pause for 30 seconds
2. 40% green, then pause for 30 seconds
3. 60% green, then pause for 30 seconds
4. 80% green, then pause for 30 seconds
5. Complete the rollout at 100% green

With five replicas, each 20% increment corresponds naturally to one pod. The
single `Service` selects all rollout pods, so traffic is distributed by normal
Kubernetes service behavior rather than precise ALB-managed weights.

## Validate Locally

Render the production manifests without applying them:

```bash
kustomize build deploy/overlays/prod
```

Applying the output with `kubectl` is only an optional local validation method.
The normal deployment path is commit, push, and ArgoCD reconciliation.

## Observe the Demo

Watch the rollout:

```bash
./scripts/watch-rollout.sh
```

The equivalent direct command is:

```bash
kubectl argo rollouts get rollout rollouts-demo -n rollouts-demo --watch
```

Print the application URL after the ALB is provisioned:

```bash
./scripts/get-alb-url.sh
```

Generate continuous traffic and print each HTTP status code:

```bash
./scripts/generate-traffic.sh
```

The request interval defaults to one second. Override it when needed:

```bash
TRAFFIC_INTERVAL_SECONDS=0.5 ./scripts/generate-traffic.sh
```

## Promote Blue to Green

Run:

```bash
./scripts/promote-blue-to-green.sh
```

The script changes the prod Kustomize image tag from `blue` to `green`, displays
the Git diff, and prints the commands required to commit and push the change:

```bash
git add deploy/overlays/prod/kustomization.yaml
git commit -m "Promote rollouts-demo from blue to green"
git push
```

After the push, ArgoCD detects the Git change. Once it synchronizes the
Application, Argo Rollouts performs the progressive canary sequence.

## ApplicationSet Onboarding

The application repository owns its deployable manifests and production
configuration. A platform repository can therefore onboard it through a
standard ApplicationSet generator by pointing at:

- repository: this application repository
- revision: the desired Git branch
- path: `deploy/overlays/prod`
- destination namespace: `rollouts-demo`

This keeps cluster-wide components such as ArgoCD, Argo Rollouts, and AWS Load
Balancer Controller in the platform layer while application rollout behavior
remains in the application repository.

## Next Phase

This phase does not include Prometheus-based analysis or automatic rollback.
The next phase will add an `AnalysisTemplate`, query Prometheus during rollout,
and deploy the `bad-green` image to verify that failed analysis automatically
rolls the application back.
