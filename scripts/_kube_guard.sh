#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

if [[ ! -f "$KUBECONFIG" ]]; then
  echo "Refusing to run: kubeconfig file not found: $KUBECONFIG" >&2
  exit 1
fi

current_context="$(kubectl --kubeconfig "$KUBECONFIG" config current-context 2>/dev/null || true)"
if [[ "$current_context" != kind-* ]]; then
  echo "Refusing to run: expected kind context, got: ${current_context:-<empty>}" >&2
  echo "KUBECONFIG: $KUBECONFIG" >&2
  exit 1
fi
