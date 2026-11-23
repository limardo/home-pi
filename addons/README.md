# addons

Installs the cluster services: ingress with Gateway API, certificates, policies, storage, database operators and observability. It needs a cluster deployed by [platform](../platform/).

## Configure

Create `values.local.yaml` next to `values.yaml`; the full structure of each key is in the subcharts' `values.yaml`.

```yaml
global:
  nfs:
    server: 192.168.x.x

ingress:
  services:
    metallb:
      addressPool:
        addresses:
          - 192.168.x.200-192.168.x.220   # free range for LoadBalancer services
  charts:
    nginx:
      gateway:
        annotations:
          metallb.universe.tf/loadBalancerIPs: 192.168.x.200
        spec:
          listeners:                      # lists are replaced, not merged: write all of them
            - name: http
              port: 80
              protocol: HTTP
              allowedRoutes:
                namespaces:
                  from: All
            - name: https
              hostname: '*.example.com'
              port: 443
              protocol: HTTPS
              allowedRoutes:
                namespaces:
                  from: All
              tls:
                mode: Terminate
                certificateRefs:
                  - kind: Secret
                    name: home-tls

security:
  services:
    clusterIssuer:
      spec:
        acme:
          email: you@example.com
          solvers:
            - selector:
                dnsZones:
                  - example.com
              dns01:
                cnameStrategy: Follow
                route53:
                  region: <aws region>
                  hostedZoneID: <hosted zone id>
                  accessKeyIDSecretRef:
                    name: aws-credentials-secret
                    key: AWS_ACCESS_KEY_ID
                  secretAccessKeySecretRef:
                    name: aws-credentials-secret
                    key: AWS_SECRET_ACCESS_KEY

observability:
  charts:
    grafana:
      alertEmail: you@example.com
      storageClass:
        share: /path/to/grafana
    loki:
      storageClass:
        share: /path/to/loki
    blackboxExporter:
      config:
        serviceMonitor:
          targets: []                     # extra URLs to monitor, outside the cluster
```

To turn a group of services off, set `<subchart>.enabled: false` in `values.yaml` (`security`, `ingress`, `storage`, `databases`, `observability`).

## Secrets

Create these before deploying. Write each one's keys in an env file (`KEY=value`, one per line) outside the repository, so the values stay out of your shell history:

| Secret | Namespace | Keys |
|---|---|---|
| `aws-credentials-secret` | `kube-security` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| `grafana-admin-secret` | `kube-observability` | `user`, `password` |
| `google-smtp-secret` | `kube-observability` | `user`, `password` (SMTP account for alert emails) |

```bash
kubectl create namespace kube-security
kubectl -n kube-security create secret generic aws-credentials-secret --from-env-file=<file>

kubectl create namespace kube-observability
kubectl -n kube-observability create secret generic grafana-admin-secret --from-env-file=<file>
kubectl -n kube-observability create secret generic google-smtp-secret --from-env-file=<file>
```

## Deploy

```bash
moon run addons:template   # check the rendered manifests
moon run addons:deploy
```

## Day to day

- **Upgrade a third-party chart**: change `charts.<name>.version` in the subchart's `values.yaml`, then build and update.
- **Upgrade the Gateway API CRDs**: `moon run addons:upgrade-gateway-api`, then build and update.
- **Upgrade NGINX Gateway Fabric**: apply its CRDs with `kubectl apply --server-side` first; Helm does not upgrade them.
