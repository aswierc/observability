#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

cluster_name="${KIND_CLUSTER_NAME:-observability}"

if ! command -v kind >/dev/null 2>&1; then
  cat >&2 <<'EOF'
kind is not installed.

Install:
  - macOS (Homebrew): brew install kind
  - or: https://kind.sigs.k8s.io/docs/user/quick-start/
EOF
  exit 1
fi

if kind get clusters | grep -qx "$cluster_name"; then
  echo "kind cluster already exists: $cluster_name"
  echo "KUBECONFIG: $KUBECONFIG"
  exit 0
fi

echo "Creating kind cluster: $cluster_name"
kind create cluster --name "$cluster_name" --kubeconfig "$KUBECONFIG"

echo "Cluster ready."
echo "KUBECONFIG: $KUBECONFIG"
