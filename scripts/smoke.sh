#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"

requests="${SMOKE_REQUESTS:-30}"
publish="${SMOKE_PUBLISH:-10}"
debug="${SMOKE_DEBUG:-0}"

run_kubectl() {
  if [ "$debug" = "1" ]; then
    kubectl --kubeconfig "$KUBECONFIG" "$@"
    return $?
  fi

  # Silence kubectl's interactive hint ("If you don't see a command prompt...") while preserving exit code.
  local out rc
  out="$(
    kubectl --kubeconfig "$KUBECONFIG" "$@" 2>&1 | sed "/If you don't see a command prompt/d"
  )"
  rc=${PIPESTATUS[0]}
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
  fi
  return "$rc"
}

echo "Context: $(kubectl --kubeconfig "$KUBECONFIG" config current-context)"
echo "Namespace: $ns"

echo "--- Waiting for deployments"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" rollout status deploy/fastapi --timeout=120s >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" rollout status deploy/laravel-api --timeout=120s >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" rollout status deploy/symfony-api --timeout=120s >/dev/null
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" rollout status deploy/symfony-consumer --timeout=120s >/dev/null
echo "OK: deployments ready."

echo "--- Generating HTTP load + publish messages"
run_kubectl -n "$ns" run smoke-curl --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc "
    set -e
    reqs=${requests}
    pubs=${publish}

    pick_ms() {
      ms_list='20 50 100 200 400 800'
      set -- \$ms_list
      n=\$#
      idx=\$((RANDOM % n + 1))
      i=1
      for ms in \$ms_list; do
        if [ \$i -eq \$idx ]; then echo \$ms; return 0; fi
        i=\$((i+1))
      done
      echo 100
    }

    i=0
    while [ \$i -lt \$reqs ]; do
      ms=\$(pick_ms)
      curl -fsS \"http://fastapi/sleep?ms=\$ms\" >/dev/null
      curl -fsS \"http://laravel-api/sleep?ms=\$ms\" >/dev/null
      curl -fsS \"http://symfony-api/sleep?ms=\$ms\" >/dev/null
      curl -fsS \"http://symfony-api/chain?ms=\$ms\" >/dev/null
      i=\$((i+1))
    done

    # Extra publish messages (optional load)
    j=0
    while [ \$j -lt \$pubs ]; do
      ms=\$(pick_ms)
      curl -fsS \"http://laravel-api/publish?ms=\$ms\" >/dev/null
      j=\$((j+1))
    done

    echo done
  " >/dev/null || { echo "FAILED: load generation (rerun with SMOKE_DEBUG=1 for details)"; exit 1; }

echo "--- Verifying Tempo has traces for services"
run_kubectl -n "$ns" run smoke-tempo --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    for svc in fastapi laravel-api symfony-api symfony-consumer; do
      out=$(curl -s "http://tempo:3200/api/search?tags=service.name%3D${svc}")
      echo "$out" | grep -q "\"traceID\"" || { echo "missing traces for $svc"; exit 1; }
    done
    echo OK
  ' >/dev/null || { echo "FAILED: tempo verification (rerun with SMOKE_DEBUG=1 for details)"; exit 1; }
echo "OK: Tempo traces present."

echo "--- Example trace IDs (paste into Grafana Tempo)"
run_kubectl -n "$ns" run smoke-traceid --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    # One end-to-end trace: symfony-api -> laravel-api (/publish) -> rabbitmq -> symfony-consumer -> fastapi
    flow_json=$(curl -fsS "http://symfony-api/flow?ms=120")
    flow_trace_id=$(echo "$flow_json" | sed -n "s/.*\\\"trace_id\\\":\\\"\\([0-9a-f]\\+\\)\\\".*/\\1/p" | head -n 1)
    if [ -z "$flow_trace_id" ]; then
      echo "flow traceID= (FAILED to extract)"
      echo "$flow_json"
      exit 1
    fi

    # Best-effort: wait for async consumer+fastapi spans to appear in Tempo for this trace
    ok=0
    if [ -n "$flow_trace_id" ]; then
      i=0
      while [ $i -lt 30 ]; do
        t=$(curl -s "http://tempo:3200/api/traces/$flow_trace_id")
        echo "$t" | grep -q symfony-consumer || { i=$((i+1)); sleep 1; continue; }
        echo "$t" | grep -q fastapi || { i=$((i+1)); sleep 1; continue; }
        ok=1
        break
      done
    fi

    if [ "$ok" = "1" ]; then
      echo "flow traceID=$flow_trace_id contains: symfony-consumer + fastapi"
    else
      echo "flow traceID=$flow_trace_id (waiting for async spans timed out)"
    fi
  ' || { echo "FAILED: trace id extraction (rerun with SMOKE_DEBUG=1 for details)"; exit 1; }

echo "--- Verifying Loki has correlated logs"
run_kubectl -n "$ns" run smoke-loki --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    end_s=$(date +%s); start_s=$((end_s-1800))
    start_ns=${start_s}000000000; end_ns=${end_s}000000000

    q() {
      svc="$1"; needle="$2"
      curl -sG "http://loki:3100/loki/api/v1/query_range" \
        --data-urlencode "query={service_name=\"${svc}\"} |= \"${needle}\"" \
        --data-urlencode "start=$start_ns" \
        --data-urlencode "end=$end_ns" \
        --data-urlencode "limit=1" \
        | grep -q "${needle}"
    }

    q fastapi slept
    q laravel-api slept
    q symfony-api slept
    q laravel-api published
    q symfony-consumer consumed
    echo OK
  ' >/dev/null || { echo "FAILED: loki verification (rerun with SMOKE_DEBUG=1 for details)"; exit 1; }
echo "OK: Loki logs present."

echo "--- Verifying Prometheus has histograms (counts > 0)"
run_kubectl -n "$ns" run smoke-prom --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    q() {
      query="$1"
      curl -sG http://prometheus-server/api/v1/query --data-urlencode "query=$query"
    }

    q "sum(app_request_duration_ms_milliseconds_count{exported_job=\"fastapi\"})" | grep -q "\"status\":\"success\""
    q "sum(app_request_duration_ms_milliseconds_count{exported_job=\"laravel-api\"})" | grep -q "\"status\":\"success\""
    q "sum(app_request_duration_ms_milliseconds_count{exported_job=\"symfony-api\"})" | grep -q "\"status\":\"success\""
    q "sum(app_consume_duration_ms_milliseconds_count{exported_job=\"symfony-consumer\"})" | grep -q "\"status\":\"success\""
    echo OK
  ' >/dev/null || { echo "FAILED: prometheus verification (rerun with SMOKE_DEBUG=1 for details)"; exit 1; }
echo "OK: Prometheus metrics present."

echo "Smoke OK."
