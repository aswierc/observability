#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"

helm uninstall otel-collector -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true
helm uninstall postgresql -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true
helm uninstall grafana -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true
helm uninstall prometheus -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true
helm uninstall loki -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true
helm uninstall tempo -n "$ns" --kubeconfig "$KUBECONFIG" 2>/dev/null || true

kubectl --kubeconfig "$KUBECONFIG" delete -k "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/infra/k8s/components/rabbitmq" --ignore-not-found

echo "Infra releases removed from namespace: $ns"
