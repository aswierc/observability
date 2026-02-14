#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

cluster_name="${KIND_CLUSTER_NAME:-observability}"

if command -v kind >/dev/null 2>&1; then
  if kind get clusters | grep -qx "$cluster_name"; then
    echo "Deleting kind cluster: $cluster_name"
    kind delete cluster --name "$cluster_name"
  else
    echo "kind cluster does not exist: $cluster_name"
  fi
else
  echo "kind is not installed; skipping cluster deletion."
fi

if [[ -f "$KUBECONFIG" ]]; then
  echo "Removing kubeconfig: $KUBECONFIG"
  rm -f -- "$KUBECONFIG"
fi
