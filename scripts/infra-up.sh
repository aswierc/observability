#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl --kubeconfig "$KUBECONFIG" apply -k "$repo_root/infra/k8s/overlays/local"

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo update >/dev/null

ns="$OBS_NAMESPACE"

helm upgrade --install tempo grafana/tempo \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 1.24.4 \
  -f "$repo_root/infra/helm/tempo-values.yaml"

helm upgrade --install loki grafana/loki \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 6.53.0 \
  -f "$repo_root/infra/helm/loki-values.yaml"

helm upgrade --install prometheus prometheus-community/prometheus \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 28.9.1 \
  -f "$repo_root/infra/helm/prometheus-values.yaml"

helm upgrade --install grafana grafana/grafana \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 10.5.15 \
  -f "$repo_root/infra/helm/grafana-values.yaml"

helm upgrade --install postgresql bitnami/postgresql \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 18.3.0 \
  -f "$repo_root/infra/helm/postgresql-values.yaml"

helm uninstall rabbitmq -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --kubeconfig "$KUBECONFIG" \
  --namespace "$ns" \
  --version 0.145.0 \
  -f "$repo_root/infra/helm/otel-collector-values.yaml"

cat <<EOF
Infra installed in namespace: $ns

Next:
  - Port-forward Grafana: make grafana
  - Grafana URL: http://localhost:3000
  - Grafana credentials: admin / admin
EOF
