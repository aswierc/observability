#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"
echo "Laravel API: http://localhost:8080"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" port-forward svc/laravel-api 8080:80
