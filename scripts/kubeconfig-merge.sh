#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
kind_kubeconfig="${KUBECONFIG}"
user_kubeconfig="${HOME}/.kube/config"

if [[ ! -f "$kind_kubeconfig" ]]; then
  echo "Missing kind kubeconfig: $kind_kubeconfig" >&2
  echo "Run: make kind-create" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$user_kubeconfig")"
touch "$user_kubeconfig"

prev_context="$(kubectl --kubeconfig "$user_kubeconfig" config current-context 2>/dev/null || true)"

backup="${user_kubeconfig}.bak.$(date +%Y%m%d%H%M%S)"
cp -f -- "$user_kubeconfig" "$backup"

tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT

KUBECONFIG="${user_kubeconfig}:${kind_kubeconfig}" kubectl config view --flatten >"$tmp"
mv -f -- "$tmp" "$user_kubeconfig"

if [[ -n "${prev_context}" ]]; then
  kubectl --kubeconfig "$user_kubeconfig" config use-context "$prev_context" >/dev/null 2>&1 || true
fi

echo "Merged kubeconfig:"
echo "  kind: $kind_kubeconfig"
echo "  into: $user_kubeconfig"
echo "  backup: $backup"
echo
echo "k9s tip:"
echo "  - safest: KUBECONFIG=\"$kind_kubeconfig\" k9s"
