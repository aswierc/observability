#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

cluster_name="${KIND_CLUSTER_NAME:-observability}"
image="${LARAVEL_IMAGE:-observability-laravel-api:dev}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Building image: $image"
docker build -t "$image" "$repo_root/apps/laravel-api"

echo "Loading image into kind cluster: $cluster_name"
kind load docker-image --name "$cluster_name" "$image"
