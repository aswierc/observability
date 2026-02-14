#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"
echo "FastAPI: http://localhost:8000"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" port-forward svc/fastapi 8000:80
