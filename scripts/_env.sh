#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export OBS_NAMESPACE="${OBS_NAMESPACE:-observability}"

default_kubeconfig="${repo_root}/.local/kube/kind-observability.kubeconfig"
export OBS_KUBECONFIG="${OBS_KUBECONFIG:-$default_kubeconfig}"
export KUBECONFIG="$OBS_KUBECONFIG"

local_dir="${repo_root}/.local"

export HELM_CONFIG_HOME="${HELM_CONFIG_HOME:-${local_dir}/helm/config}"
export HELM_CACHE_HOME="${HELM_CACHE_HOME:-${local_dir}/helm/cache}"
export HELM_DATA_HOME="${HELM_DATA_HOME:-${local_dir}/helm/data}"

mkdir -p -- \
  "$(dirname -- "$KUBECONFIG")" \
  "$HELM_CONFIG_HOME" \
  "$HELM_CACHE_HOME" \
  "$HELM_DATA_HOME"

if [[ "$KUBECONFIG" != "$repo_root"/.local/* ]]; then
  echo "Refusing to run: KUBECONFIG must be under repo .local/ for safety." >&2
  echo "Got: $KUBECONFIG" >&2
  exit 1
fi
