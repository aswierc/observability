#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"
echo "Symfony API: http://localhost:8081"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" port-forward svc/symfony-api 8081:80
