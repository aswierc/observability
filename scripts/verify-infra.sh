#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_kube_guard.sh"

ns="$OBS_NAMESPACE"
svc_name="tg-verify"
log_msg="hello-from-otel-logs"

echo "Context: $(kubectl --kubeconfig "$KUBECONFIG" config current-context)"
echo "Namespace: $ns"

echo "--- Generating traces via OTLP -> Collector"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run tg-traces --rm -i --restart=Never \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  -- traces \
  --otlp-endpoint otel-collector:4317 \
  --otlp-insecure \
  --duration 10s \
  --rate 5 \
  --service "$svc_name" >/dev/null

echo "--- Generating logs via OTLP -> Collector"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run tg-logs --rm -i --restart=Never \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  -- logs \
  --otlp-endpoint otel-collector:4317 \
  --otlp-insecure \
  --duration 10s \
  --rate 5 \
  --service "$svc_name" \
  --body "$log_msg" >/dev/null

echo "--- Verifying Collector exporter counters (Tempo + Loki)"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run curl --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    m=$(curl -s http://otel-collector:8888/metrics)
    echo "$m" | grep -E "otelcol_exporter_sent_spans_total\\{.*exporter=\\\"otlp_grpc/tempo\\\"" | head -n 1
    echo "$m" | grep -E "otelcol_exporter_sent_log_records_total\\{.*exporter=\\\"otlp_http/loki\\\"" | head -n 1
  ' | sed -n '1,4p'

echo "--- Verifying Tempo has traces for service.name=$svc_name"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run curl --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc "
    set -e
    out=\$(curl -s \"http://tempo:3200/api/search?tags=service.name%3D${svc_name}\")
    echo \"\$out\" | head -c 400; echo
    echo \"\$out\" | grep -q '\"traceID\"'
  " >/dev/null
echo "OK: Tempo search returned trace(s)."

echo "--- Verifying Prometheus scrapes Collector metrics endpoint"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run curl --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc '
    set -e
    curl -sG http://prometheus-server/api/v1/query --data-urlencode "query=up{job=\"otel-collector\"}" \
      | grep -q "\"value\":\\[[0-9.]*,\"1\"\\]"
  ' >/dev/null
echo "OK: Prometheus up{job=\"otel-collector\"} == 1."

echo "--- Verifying Loki contains the OTLP log line"
kubectl --kubeconfig "$KUBECONFIG" -n "$ns" run curl --rm -i --restart=Never \
  --image=curlimages/curl:8.6.0 \
  --command -- sh -lc "
    set -e
    end_s=\$(date +%s); start_s=\$((end_s-600))
    start_ns=\${start_s}000000000; end_ns=\${end_s}000000000
    curl -sG 'http://loki:3100/loki/api/v1/query_range' \
      --data-urlencode 'query={service_name=\"${svc_name}\"} |= \"${log_msg}\"' \
      --data-urlencode \"start=\$start_ns\" \
      --data-urlencode \"end=\$end_ns\" \
      --data-urlencode 'limit=1' \
      | grep -q \"${log_msg}\"
  " >/dev/null
echo "OK: Loki query returned log(s)."

echo "All checks passed."
