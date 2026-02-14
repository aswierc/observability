#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/symfony-build.sh"

kubectl --kubeconfig "$KUBECONFIG" apply -k "$repo_root/infra/k8s/apps/symfony-api"
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout restart deploy/symfony-api >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout status deploy/symfony-api --timeout=120s
