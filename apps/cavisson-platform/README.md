# Cavisson Platform Helm Chart

This Helm chart deploys a Cavisson tenant instance with all required components.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x
- Cavisson Operator installed (see `helm/cavisson-operator`)
- Storage class supporting ReadWriteMany (RWX) for the primary PVC
- NGINX Ingress Controller installed in the cluster

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| Controller | StatefulSet | UI portal (port 4444) and data collection (port 443) |
| PostgreSQL | StatefulSet | Metadata and configuration database |
| MongoDB | StatefulSet | Alert history storage |
| Redis | Deployment | Session cache |
| Ingress (UI) | Ingress | Routes `ui.<tenantId>.<baseDomain>` → port 4444 |
| Ingress (Data) | Ingress | Routes `data.<tenantId>.<baseDomain>` → port 443 |

## Ingress Design

Both services are exposed on **standard HTTPS port 443** using host-based routing. No non-standard
ports are needed externally. NGINX terminates external TLS and re-encrypts to the controller's
internal HTTPS endpoints.

```
Internet (HTTPS :443)
        │
   NGINX Ingress
   LoadBalancer IP
        │
   ┌────┴─────────────────────┐
   │ SNI / Host header        │
   ▼                          ▼
ui.tenant1.cav-test.com   data.tenant1.cav-test.com
        │                          │
controller:4444            controller:443
   (UI Portal)            (Data Collection)
```

DNS entries required (same IP, different hostnames):

```
ui.tenant1.cav-test.com   →  <ingress-lb-ip>
data.tenant1.cav-test.com →  <ingress-lb-ip>
```

## Installation

### Step 1 — Install the NGINX Ingress Controller (once per cluster)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Get the public IP assigned to it:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# NAME                       TYPE           CLUSTER-IP   EXTERNAL-IP
# ingress-nginx-controller   LoadBalancer   10.x.x.x     20.40.80.10  ← use this
```

### Step 2 — Install cert-manager (optional, for automatic TLS)

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
```

Create a ClusterIssuer for Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Step 3 — Deploy a tenant

```bash
helm install cavisson-tenant1 ./helm/cavisson-platform \
  --namespace cavisson-tenant1 \
  --create-namespace \
  -f examples/tenant1-values.yaml
```

After deployment, verify the Ingress resources:

```bash
kubectl get ingress -n cavisson-tenant1
# NAME                         CLASS   HOSTS                          ADDRESS
# cavisson-tenant1-ui          nginx   ui.tenant1.cav-test.com        20.40.80.10
# cavisson-tenant1-data        nginx   data.tenant1.cav-test.com      20.40.80.10
```

### Step 4 — Configure DNS

Point both hostnames at the Ingress LoadBalancer IP:

```
ui.tenant1.cav-test.com   A  20.40.80.10
data.tenant1.cav-test.com A  20.40.80.10
```

Services are then accessible at:

- **UI (Portal):** `https://ui.tenant1.cav-test.com`
- **Data collection:** `https://data.tenant1.cav-test.com`

## Deploying a Second Tenant

Each tenant gets its own namespace and its own pair of Ingress resources. The shared NGINX
LoadBalancer IP routes traffic using the hostname.

```bash
helm install cavisson-tenant2 ./helm/cavisson-platform \
  --namespace cavisson-tenant2 \
  --create-namespace \
  -f examples/tenant2-values.yaml
```

DNS entries for tenant2:

```
ui.tenant2.cav-test.com   A  20.40.80.10   ← same IP
data.tenant2.cav-test.com A  20.40.80.10
```

## Configuration Reference

### Core

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tenantId` | Unique tenant identifier (used in hostnames) | `tenant1` |
| `baseDomain` | Base domain for hostname construction | `cav-test.com` |

### Controller Service Ports

| Parameter | Description | Default |
|-----------|-------------|---------|
| `controller.service.uiPort` | UI / Portal HTTPS port | `4444` |
| `controller.service.dataPort` | Data collection HTTPS port | `443` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Deploy Ingress resources | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Annotations on both Ingress resources | see values.yaml |
| `ingress.tls.enabled` | Enable TLS on both Ingresses | `true` |
| `ingress.tls.certManager.enabled` | Add cert-manager annotation | `false` |
| `ingress.tls.certManager.issuerName` | cert-manager issuer name | `letsencrypt-prod` |
| `ingress.tls.certManager.issuerKind` | `ClusterIssuer` or `Issuer` | `ClusterIssuer` |
| `ingress.tls.uiSecretName` | TLS secret for UI (auto: `<tenantId>-ui-tls`) | `""` |
| `ingress.tls.dataSecretName` | TLS secret for data (auto: `<tenantId>-data-tls`) | `""` |
| `ingress.externalDns.enabled` | Add ExternalDNS hostname annotations | `false` |
| `ingress.externalDns.ttl` | DNS TTL in seconds | `60` |
| `ingress.ui.annotations` | Extra annotations for the UI Ingress only | `{}` |
| `ingress.data.annotations` | Extra annotations for the data Ingress only | `{}` |

### On-Premises (MetalLB + manual DNS)

On-prem clusters without a cloud load balancer: deploy MetalLB, configure an IP pool, and the
NGINX Ingress LoadBalancer Service will receive an IP from that pool. Create DNS records manually
pointing to that IP.

```bash
# Install MetalLB
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace
```

No changes to this Helm chart are needed — the Ingress resources work identically.

### ExternalDNS (automatic DNS registration)

Enable ExternalDNS in values to have DNS records created automatically when Ingress resources
are applied:

```yaml
ingress:
  externalDns:
    enabled: true
    ttl: "60"
```

Requires ExternalDNS deployed in the cluster with credentials for your DNS provider.

## Upgrade

```bash
helm upgrade cavisson-tenant1 ./helm/cavisson-platform \
  --namespace cavisson-tenant1 \
  -f examples/tenant1-values.yaml
```

## Uninstall

```bash
helm uninstall cavisson-tenant1 --namespace cavisson-tenant1
kubectl delete namespace cavisson-tenant1
```

PVCs are not deleted automatically. Remove them manually if needed:

```bash
kubectl delete pvc -n cavisson-tenant1 --all
```

## Storage Classes by Cloud Provider

| Provider | Recommended class | Notes |
|----------|------------------|-------|
| AKS | `azurefile-csi` | Azure Files, supports RWX |
| EKS | `efs-sc` | Amazon EFS, supports RWX |
| GKE | `filestore-csi` | Google Filestore, supports RWX |
| On-prem | `nfs` / `cephfs` | NFS or CephFS |
