#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# consumer uses the same image as symfony-api
"$repo_root/scripts/symfony-build.sh"

kubectl --kubeconfig "$KUBECONFIG" apply -k "$repo_root/infra/k8s/apps/symfony-consumer"
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout restart deploy/symfony-consumer >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$OBS_NAMESPACE" rollout status deploy/symfony-consumer --timeout=120s
