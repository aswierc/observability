#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

cluster_name="${KIND_CLUSTER_NAME:-observability}"
image="${FASTAPI_IMAGE:-observability-fastapi:dev}"

echo "Building image: $image"
docker build -t "$image" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/apps/fastapi"

echo "Loading image into kind cluster: $cluster_name"
kind load docker-image --name "$cluster_name" "$image"
