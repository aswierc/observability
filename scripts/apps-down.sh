#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl --kubeconfig "$KUBECONFIG" delete -k "$repo_root/infra/k8s/apps/symfony-consumer" --ignore-not-found
kubectl --kubeconfig "$KUBECONFIG" delete -k "$repo_root/infra/k8s/apps/symfony-api" --ignore-not-found
kubectl --kubeconfig "$KUBECONFIG" delete -k "$repo_root/infra/k8s/apps/laravel-api" --ignore-not-found
kubectl --kubeconfig "$KUBECONFIG" delete -k "$repo_root/infra/k8s/apps/fastapi" --ignore-not-found
