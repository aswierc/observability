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
                ┌────────────────────┐       ┌──────────────┐
Client → HTTP → │ laravel-api        │ ──HTTP→ │ fastapi     │
                │ (trace init)       │        └──────────────┘
                │                    │
                │ ──HTTP→ symfony-api│ ──RabbitMQ→ async -> consumer
                └────────────────────┘
                    │               │
                    │               │
                    │               ↓
                 PostgreSQL         RabbitMQ

Logs + Metrics + Traces
                ↓
        OpenTelemetry Collector
                ↓
    Grafana ⇄ Tempo (Traces), Loki (Logs), Prometheus (Metrics)
```

---

## 📦 Repo Structure (suggested)

```
observability/
├── apps/
│   ├── laravel-api/
│   ├── symfony-api/
│   └── fastapi/
├── infra/
│   ├── docker/
│   │   └── compose/
│   └── k8s/
├── otel/
│   └── collector/
│       └── config.yaml
├── docs/
│   ├── scenarios.md
│   └── dashboards.md
├── scripts/
│   ├── kind-create.sh
│   ├── kind-destroy.sh
│   └── seed.sh
├── Makefile
└── README.md
```

---

## 🧹 Quick Start

### Local with Docker Compose

```bash
git clone https://github.com/aswierc/observability.git
cd observability
docker compose -f infra/docker/compose/docker-compose.yml up -d
```

Grafana will be available at `http://localhost:3000`.

---

### Local with Kubernetes (kind)

```bash
./scripts/kind-create.sh
kubectl apply -k infra/k8s/overlays/local
kubectl -n observability port-forward svc/grafana 3000:3000
```

Open `http://localhost:3000` in your browser.

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
GET /api/chain → laravel → fastapi → symfony
```

Expected: One distributed trace with correct spans and context propagation across languages.

### 2. Database trace

```
GET /api/db → laravel
           → PostgreSQL query
```

Expected: DB span with semantic attributes and timeline.

### 3. Async trace via RabbitMQ

```
Publish in laravel
Consume in symfony
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
☐ Message queue trace propagation
☐ Prometheus dashboards
☐ Load test and SLO alerts
☐ CI integration with tracing validation
