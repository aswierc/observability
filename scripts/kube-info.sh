#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

echo "OBS_NAMESPACE: $OBS_NAMESPACE"
echo "KUBECONFIG: $KUBECONFIG"
echo "HELM_CONFIG_HOME: $HELM_CONFIG_HOME"
echo "HELM_CACHE_HOME: $HELM_CACHE_HOME"
echo "HELM_DATA_HOME: $HELM_DATA_HOME"

if [[ ! -f "$KUBECONFIG" ]]; then
  echo "kubectl: kubeconfig file not found (cluster not created yet)."
  exit 0
fi

echo "---"
kubectl --kubeconfig "$KUBECONFIG" config current-context
echo "---"
kubectl --kubeconfig "$KUBECONFIG" get ns
