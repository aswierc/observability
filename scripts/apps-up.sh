#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/fastapi-up.sh"
"$repo_root/scripts/laravel-up.sh"
"$repo_root/scripts/symfony-up.sh"
"$repo_root/scripts/symfony-consumer-up.sh"
