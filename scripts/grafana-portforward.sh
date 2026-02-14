#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"

echo "Grafana: http://localhost:3000 (admin/admin)"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" port-forward svc/grafana 3000:80
