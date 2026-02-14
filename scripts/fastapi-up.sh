#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/fastapi-build.sh"

kubectl --kubeconfig "$KUBECONFIG" apply -k "$repo_root/infra/k8s/apps/fastapi"
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout restart deploy/fastapi >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout status deploy/fastapi --timeout=90s
