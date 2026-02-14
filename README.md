# Observability Monorepo

Observability Monorepo for distributed tracing, metrics and logs across multiple services.

This repo is designed for testing OpenTelemetry (OTel) traces/spans, propagation, logs correlation and metrics in a polyglot environment with PHP & Python.

## 🚀 Overview

This project contains multiple services and infrastructure needed to explore full end‑to‑end observability:

| Component | Language / Framework | Purpose |
|-----------|----------------------|---------|
| Laravel API | PHP (Laravel) | Entry point and HTTP chain |
| Symfony API | PHP (Symfony) | Downstream API + async consumer |
| FastAPI | Python (FastAPI) | Downstream microservice |
| PostgreSQL | SQL | Relational database |
| RabbitMQ | Message queue | Async trace propagation |
| OpenTelemetry Collector | OTel | Central telemetry ingest |
| Grafana | UI | Dashboard & trace exploration |
| Tempo | Traces | Store traces |
| Loki | Logs | Store logs |
| Prometheus | Metrics | Store metrics |

This stack lets you visualize traces, metrics, and logs in one place and explore trace context propagation, HTTP spans, DB spans, and logs correlation.

---

## 🎯 Objectives

We want to validate, explore and demonstrate:

- Distributed tracing across multiple services and languages.
- Context propagation (W3C trace context) between services via HTTP and RabbitMQ.
- Log correlation: logs tagged with `trace_id`/`span_id`.
- Metrics with Prometheus: latency, error rate, throughput.
- Collector‑centric architecture with OTLP as central ingestion.

---

## 🧡 Architecture

```
Client → HTTP → symfony-api ──HTTP→ laravel-api ──HTTP→ fastapi
                 │
                 └─ /flow ─HTTP→ laravel-api (/publish) ─RabbitMQ→ symfony-consumer ─HTTP→ fastapi

Logs + Metrics + Traces
                ↓
        OpenTelemetry Collector
                ↓
    Grafana ⇄ Tempo (Traces), Loki (Logs), Prometheus (Metrics)
```

---

## 🧹 Quick Start

### Local with Kubernetes (kind) — recommended (safe)

```bash
make kind-create
make up
make smoke
make grafana
```

Grafana: `http://localhost:3000` (admin/admin)
`make smoke` prints a `flow traceID=...` you can paste into Grafana → Explore → Tempo.

Safety notes:
- All scripts use **repo-local** `KUBECONFIG` under `./.local/` and refuse to run otherwise.
- `helm` also uses **repo-local** `HELM_*_HOME` under `./.local/helm/*`.

### k9s

Safest:

```bash
KUBECONFIG=./.local/kube/kind-observability.kubeconfig k9s
```

Or merge the kind context into your `~/.kube/config` (creates a timestamped backup):

```bash
make kubeconfig-merge
```

---

## 🗘️ Config Notes

### OpenTelemetry Collector

Collector routes OTLP from services to:

- Tempo for traces
- Loki for logs
- Prometheus for metrics

Collector config includes receivers, processors and exporters.

---

## 🧪 Example User Scenarios

### 1. HTTP chain trace

```
GET /chain → symfony-api → laravel-api → fastapi
```

Expected: One distributed trace with correct spans and context propagation across languages.

### 2. Database trace

```
GET /db → laravel-api
           → PostgreSQL query
```

Expected: DB span with semantic attributes and timeline.

### 3. Async trace via RabbitMQ

```
GET /flow → symfony-api
        → laravel-api (/publish) → RabbitMQ → symfony-consumer → fastapi
```

Expected: Trace continues across message broker boundaries.

---

## 📊 Observability Signals

| Signal | Purpose |
|--------|---------|
| Traces | Request flows across services |
| Logs | Correlated with trace IDs |
| Metrics | p95/p99 latency, throughput, errors |

---

## 📌 Best Practices

- Set consistent `service.name`, `service.version` and environment tags.
- Use W3C trace context propagation across HTTP and messaging.
- Correlate logs with trace IDs for unified exploration.

---

## 📑 License

MIT

---

## 🔨 Roadmap

☑️ Local Dev Environment
☑️ Message queue trace propagation
☑️ Prometheus dashboards (basic P95)
☐ Load test + SLO alerts
☐ CI integration with tracing validation
