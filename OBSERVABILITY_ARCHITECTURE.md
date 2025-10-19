# OpenTelemetry Observability Lab - Architecture & Design Decisions

**Last Updated:** 2025-10-19
**Status:** Production-Ready Architecture (Post-Duplication Fix)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Original Goals](#original-goals)
3. [High-Level Architecture](#high-level-architecture)
4. [The Conundrum: Metric Duplication](#the-conundrum-metric-duplication)
5. [Inflection Point: Option A Decision](#inflection-point-option-a-decision)
6. [Final Architecture](#final-architecture)
7. [Data Flow Diagrams](#data-flow-diagrams)
8. [Code-to-Architecture Mapping](#code-to-architecture-mapping)
9. [Verification & Testing](#verification--testing)
10. [Future Enhancements](#future-enhancements)

---

## Executive Summary

This document captures the end-to-end observability architecture for a Flask-based task management application deployed via Jenkins CI/CD pipeline. The system implements the **three pillars of observability**: traces, metrics, and logs using OpenTelemetry (OTel) and the Prometheus/Grafana stack.

**Key Architecture Principle:**
*Separation of Concerns* - OpenTelemetry handles distributed tracing and logging, while Prometheus client library handles application metrics. This eliminates duplication and provides a clean, maintainable architecture.

---

## Original Goals

### Business Objectives
- Build a production-grade observability stack for microservices
- Implement SLI/SLO dashboards for service reliability tracking
- Enable end-to-end request tracing across services
- Centralize log aggregation with trace correlation

### Technical Requirements
1. **Traces**: Capture HTTP requests, database queries, and cross-service calls
2. **Metrics**: Track request rates, error rates, latency percentiles, and custom business metrics
3. **Logs**: Structured JSON logging with automatic trace ID injection
4. **Dashboards**: Real-time visualization in Grafana
5. **Portability**: Works across development (localhost), VM, and cloud environments

---

## High-Level Architecture

### Observability Stack Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER / BROWSER                              │
│                 (http://192.168.122.250:8080)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FRONTEND (NGINX:80)                              │
│  • Serves static HTML/CSS/JS                                        │
│  • Proxies /api/* → backend:5000/api/*                              │
│  • Dynamic links to observability tools                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  FLASK BACKEND (Port 5000)                          │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ INSTRUMENTATION LAYER                                         │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │ ① OpenTelemetry SDK (Traces & Logs)                           │ │
│  │    • FlaskInstrumentor: HTTP request/response spans           │ │
│  │    • SQLAlchemyInstrumentor: Database query spans             │ │
│  │    • OTLP Exporter → sends to collector:4318                  │ │
│  │                                                               │ │
│  │ ② Prometheus Client (Metrics)                                 │ │
│  │    • http_requests_total (Counter)                            │ │
│  │    • http_request_duration_seconds (Histogram)                │ │
│  │    • http_errors_total (Counter)                              │ │
│  │    • Exposed at /metrics endpoint                             │ │
│  │                                                               │ │
│  │ ③ SQLite Database                                             │ │
│  │    • /app/data/tasks.db (persistent volume)                   │ │
│  └───────────────────────────────────────────────────────────────┘ │
└────────────────────────┬──────────────────┬─────────────────────────┘
                         │                  │
                         │ OTLP             │ Prometheus scrape
                         │ (traces/logs)    │ (metrics /metrics)
                         │                  │
                         ▼                  ▼
┌────────────────────────────────┐  ┌──────────────────────────────┐
│  OTEL COLLECTOR (Port 4318)    │  │  PROMETHEUS (Port 9090)      │
│  ┌──────────────────────────┐  │  │  ┌────────────────────────┐  │
│  │ Receivers: OTLP          │  │  │  │ Scrape Configs:        │  │
│  │ Processors:              │  │  │  │  • flask-backend:5000  │  │
│  │  • resource              │  │  │  │  • otel-collector:8888 │  │
│  │  • batch                 │  │  │  │  • tempo, loki, etc.   │  │
│  │  • memory_limiter        │  │  │  │                        │  │
│  │                          │  │  │  │ Storage: TSDB          │  │
│  │ Exporters:               │  │  │  └────────────────────────┘  │
│  │  • Tempo (traces)        │  │  └──────────────────────────────┘
│  │  • Loki (logs)           │  │
│  │  • logging (debug)       │  │
│  └──────────────────────────┘  │
└────────────────────────────────┘
                │
                │
                ▼
┌──────────────────────────────────────────────────────────────┐
│                    STORAGE BACKENDS                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ TEMPO        │  │ LOKI         │  │ PROMETHEUS   │       │
│  │ (Traces)     │  │ (Logs)       │  │ (Metrics)    │       │
│  │ Port: 3200   │  │ Port: 3100   │  │ Port: 9090   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GRAFANA (Port 3000)                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Data Sources:                                             │  │
│  │  • Prometheus (uid: prometheus) - metrics queries         │  │
│  │  • Tempo (uid: tempo) - trace queries                     │  │
│  │  • Loki (uid: loki) - log queries                         │  │
│  │                                                           │  │
│  │ Dashboards:                                               │  │
│  │  • SLI/SLO Dashboard - service availability, latency      │  │
│  │  • End-to-End Tracing - distributed request flows         │  │
│  │  • Explore - ad-hoc queries across all data sources       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Conundrum: Metric Duplication

### Problem Discovery

During implementation, we discovered that **the same metric names appeared twice** in Prometheus with different `job` labels:

```
http_requests_total{job="flask-backend", ...}            # From prometheus_client
http_requests_total{job="otel-collector-prometheus-exporter", ...}  # From OTel SDK
```

### Root Cause

We had **two parallel metric pipelines** feeding Prometheus:

**Pipeline 1: OTel SDK → Collector → Prometheus**
```
Flask (OTel SDK)
  ↓ meter.create_counter("http_requests_total")
  ↓ OTLP export to collector:4318
  ↓ Collector receives metrics
  ↓ TWO exporters active:
     ├─→ prometheus exporter (port 8889) → Prometheus scrapes it
     └─→ prometheusremotewrite → pushes to Prometheus
```

**Pipeline 2: Prometheus Client → Prometheus**
```
Flask (prometheus_client)
  ↓ Counter("http_requests_total")
  ↓ Exposed at /metrics endpoint
  ↓ Prometheus scrapes backend:5000/metrics
```

### Impact

1. **Duplicate series in Prometheus** - same metric name with different job labels
2. **Dashboard confusion** - queries like `sum(http_requests_total)` counted events twice
3. **Inconsistent "No data" errors** - UID mismatches between dashboard and datasource
4. **Wasted storage** - storing identical metrics from two sources

---

## Inflection Point: Option A Decision

### Options Considered

We evaluated three approaches to resolve the duplication:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A** | **Remove OTel metrics from Prometheus** | Single source of truth; clean architecture; SLI dashboards work immediately | Lose OTel metrics correlation (but traces/logs unaffected) |
| **B** | Rename prometheus_client metrics (`app_http_requests_total`) | Keep both systems; no duplication | Must update all dashboard queries |
| **C** | Filter dashboards by `{job="flask-backend"}` | Minimal code changes | Duplicates still stored; easy to forget filters |

### Why We Chose Option A

**Decision Rationale:**

1. **Simplicity** - Single metric source is easier to reason about and maintain
2. **OTel Traces are the Real Value** - Distributed tracing context is preserved (most valuable OTel feature)
3. **Logs Still Flow Through Collector** - Trace correlation works via OTLP log export to Loki
4. **Prometheus Client is Purpose-Built** - Designed specifically for app-level SLI metrics
5. **No Dashboard Changes Needed** - Existing queries work immediately

**Trade-off Accepted:**

We lose the ability to send application metrics through the OTel collector for enrichment. However:
- Metrics are simple counters/histograms (no complex processing needed)
- Traces provide the distributed context we need
- Prometheus client metrics are sufficient for SLI/SLO dashboards

---

## Final Architecture

### The Three Pillars (Post-Fix)

```
┌────────────────────────────────────────────────────────────┐
│              FLASK BACKEND OBSERVABILITY                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │  PILLAR 1: TRACES (OpenTelemetry)                │     │
│  │  • FlaskInstrumentor: HTTP spans                  │     │
│  │  • SQLAlchemyInstrumentor: DB query spans         │     │
│  │  • Export: OTLP → Collector → Tempo              │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │  PILLAR 2: METRICS (Prometheus Client)           │     │
│  │  • http_requests_total                            │     │
│  │  • http_request_duration_seconds                  │     │
│  │  • http_errors_total                              │     │
│  │  • Export: /metrics → Prometheus scrape           │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │  PILLAR 3: LOGS (OpenTelemetry)                  │     │
│  │  • Structured JSON logging                        │     │
│  │  • Automatic trace_id/span_id injection           │     │
│  │  • Export: OTLP → Collector → Loki               │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Request Flow (Detailed)

```
1. User Request
   Browser → http://192.168.122.250:8080/api/tasks
      ↓
2. Nginx Proxy
   frontend:80/api/* → backend:5000/api/*
      ↓
3. Flask @app.before_request
   • Start timer (g.prom_start_time)
   • Log "Incoming request" (includes trace_id)
   • OTel creates root span
      ↓
4. Route Handler (e.g., GET /api/tasks)
   • OTel span: "get_all_tasks"
      ↓
5. Database Query
   • OTel SQLAlchemy creates child span: "SELECT /app/data/tasks.db"
   • Record duration in span attributes
      ↓
6. Flask @app.after_request
   • Calculate request duration
   • Increment prometheus_client metrics:
     - prom_http_requests_total.labels(...).inc()
     - prom_http_request_duration_seconds.labels(...).observe(duration)
   • Log "Request completed" (includes trace_id, span_id, duration)
   • OTel closes spans
      ↓
7. Background Export
   • OTel spans → OTLP → Collector → Tempo
   • OTel logs → OTLP → Collector → Loki
   • Prometheus scrapes /metrics every 15s
      ↓
8. Grafana Queries
   • Tempo: Fetch trace by trace_id
   • Prometheus: Query http_requests_total{job="flask-backend"}
   • Loki: Query logs with {service_name="flask-backend"} |= "trace_id"
```

---

## Data Flow Diagrams

### Traces Flow

```
┌──────────────┐
│ Flask Route  │
│  Handler     │ ① Creates span with FlaskInstrumentor
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ SQLAlchemy   │
│  Query       │ ② Creates child span with SQLAlchemyInstrumentor
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ BatchSpanProcessor│ ③ Batches spans (10s timeout)
└──────┬───────────┘
       │
       ▼ OTLP/HTTP
┌──────────────────┐
│ OTel Collector   │ ④ Receives spans at :4318/v1/traces
│  (receiver: otlp)│
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Tempo            │ ⑤ Stores traces in /tmp/tempo
│  (port 3200)     │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Grafana          │ ⑥ Queries traces via Tempo datasource
│  (Explore/       │    Example: trace ID lookup from log
│   Dashboard)     │
└──────────────────┘
```

### Metrics Flow

```
┌──────────────┐
│ Flask Request│
│  Middleware  │ ① Increments prometheus_client counters/histograms
└──────┬───────┘
       │
       ▼
┌─────────────────────┐
│ /metrics Endpoint   │ ② Exposes metrics in Prometheus text format
│  (GET /metrics)     │    Example: http_requests_total{...} 42
└──────┬──────────────┘
       │
       ▼ HTTP Scrape (15s interval)
┌─────────────────────┐
│ Prometheus          │ ③ Scrapes backend:5000/metrics
│  (scrape_config:    │    job="flask-backend"
│   flask-backend)    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Prometheus TSDB     │ ④ Stores time-series data
│  (retention: 15d)   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Grafana             │ ⑤ Queries via Prometheus datasource
│  (SLI/SLO Dashboard)│    Example: rate(http_requests_total[5m])
└─────────────────────┘
```

### Logs Flow

```
┌──────────────┐
│ Flask Logger │
│  (stdlib)    │ ① Emits log with trace_id in extra fields
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ LoggingHandler   │ ② OTel bridges stdlib logs to OTel LogRecordProcessor
│  (OTel SDK)      │
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ BatchLogRecordProcessor│ ③ Batches log records
└──────┬─────────────────┘
       │
       ▼ OTLP/HTTP
┌──────────────────┐
│ OTel Collector   │ ④ Receives logs at :4318/v1/logs
│  (receiver: otlp)│    Adds resource attributes
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Loki             │ ⑤ Stores logs with labels:
│  (port 3100)     │    {service_name="flask-backend", level="info"}
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Grafana          │ ⑥ Queries logs via Loki datasource
│  (Explore/Logs)  │    Can filter by trace_id for correlation
└──────────────────┘
```

---

## Code-to-Architecture Mapping

### Backend: `backend/app.py`

**Lines 1-77: OpenTelemetry Setup**
```python
# OTel SDK initialization
tracer_provider = TracerProvider(resource=resource)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
logger_provider = LoggerProvider(resource=resource)

# Export configuration
otlp_trace_exporter = OTLPSpanExporter(endpoint="http://otel-collector:4318/v1/traces")
otlp_log_exporter = OTLPLogExporter(endpoint="http://otel-collector:4318/v1/logs")
```
**Maps to:** Traces & Logs pillars in architecture diagram

---

**Lines 92-109: Prometheus Client Metrics**
```python
prom_http_requests_total = Counter('http_requests_total', 'Total HTTP requests',
                                    ['method', 'endpoint', 'status_code'])
prom_http_request_duration_seconds = Histogram('http_request_duration_seconds', ...)
prom_http_errors_total = Counter('http_errors_total', ...)
```
**Maps to:** Metrics pillar → Prometheus scrape flow

---

**Lines 150-163: Before Request Middleware**
```python
@app.before_request
def before_request():
    request.start_time = time.time()
    g.prom_start_time = time.time()  # Timer for prometheus_client
    # Logging with trace context
```
**Maps to:** Step 3 in "Request Flow (Detailed)"

---

**Lines 165-211: After Request Middleware**
```python
@app.after_request
def after_request(response):
    # Record Prometheus metrics (ONLY source for metrics now)
    prom_http_requests_total.labels(...).inc()
    prom_http_request_duration_seconds.labels(...).observe(prom_duration)
    # Log with trace_id for correlation
```
**Maps to:** Step 6 in "Request Flow (Detailed)" + Metrics flow

---

**Lines 435-438: /metrics Endpoint**
```python
@app.route('/metrics', methods=['GET'])
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
```
**Maps to:** Step ② in Metrics flow diagram

---

### Collector: `otel-collector/otel-collector-config.yml`

**Lines 1-13: OTLP Receivers**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```
**Maps to:** Central hub for receiving traces/logs from Flask

---

**Lines 58-80: Exporters (Post-Fix)**
```yaml
exporters:
  otlp/tempo:
    endpoint: tempo:4317
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  # Prometheus exporters REMOVED (lines 77-80 comment)
```
**Maps to:** Traces → Tempo, Logs → Loki (metrics bypassed)

---

**Lines 90-105: Service Pipelines**
```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlp/tempo, logging]
    # metrics pipeline REMOVED
    logs:
      receivers: [otlp]
      exporters: [loki, logging]
```
**Maps to:** Architecture decision - no metrics through collector

---

### Prometheus: `otel-collector/prometheus.yml`

**Lines 26-33: Flask Backend Scrape**
```yaml
- job_name: 'flask-backend'
  static_configs:
    - targets: ['backend:5000']
      labels:
        service: 'flask-backend'
```
**Maps to:** Step ③ in Metrics flow - Prometheus scrapes /metrics

---

**Lines 21-23: Removed Collector Exporter Scrape**
```yaml
# NOTE: otel-collector-prometheus-exporter job removed
# Collector no longer exports Prometheus metrics (only traces/logs).
```
**Maps to:** Architecture fix - eliminated duplicate scrape job

---

### Frontend: `frontend/app.js`

**Lines 1-3: Dynamic API URL**
```javascript
const API_URL = '/api';  // Proxied by Nginx to backend:5000/api
```
**Maps to:** Step 2 in Request flow - Nginx proxy configuration

---

**Lines 17-35: Dynamic Observability Links**
```javascript
function setupDynamicLinks() {
    const host = window.location.hostname;
    const links = {
        'link-grafana': `http://${host}:3000`,
        'link-prometheus': `http://${host}:9090`,
        ...
    };
}
```
**Maps to:** Cross-environment portability - works on localhost, VM, cloud

---

### Frontend: `frontend/default.conf`

**Lines 14-34: API Proxy**
```nginx
location /api/ {
    proxy_pass http://backend:5000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```
**Maps to:** Same-origin API access, eliminates CORS issues

---

### Grafana: `grafana/provisioning/datasources/datasources.yml`

**Lines 4-18: Prometheus Datasource**
```yaml
- name: Prometheus
  type: prometheus
  url: http://prometheus:9090
  uid: prometheus
  isDefault: true
```
**Maps to:** Grafana → Prometheus query path for SLI dashboards

---

**Lines 20-55: Tempo Datasource**
```yaml
- name: Tempo
  type: tempo
  url: http://tempo:3200
  uid: tempo
  tracesToLogs:
    datasourceUid: 'loki'
```
**Maps to:** Trace → Log correlation (click trace_id in Tempo → jumps to Loki logs)

---

### Dashboards: `grafana/dashboards/sli-slo-dashboard.json`

**Lines 72-74: Service Availability Query**
```json
{
  "expr": "100 * (1 - (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))))",
  "datasource": {"type": "prometheus", "uid": "prometheus"}
}
```
**Maps to:** SLI calculation using prometheus_client metrics from Flask /metrics

---

## Verification & Testing

### Post-Deployment Checks

**1. Verify Single Metric Source**
```bash
# On Prometheus (http://192.168.122.250:9090)
count by (__name__, job) (http_requests_total)

# Expected Output:
# http_requests_total{job="flask-backend"} = 1
# (Only ONE job, not two!)
```

**2. Test /metrics Endpoint**
```bash
curl http://192.168.122.250:5000/metrics | grep http_requests

# Expected Output:
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
# http_requests_total{endpoint="get_tasks",method="GET",status_code="200"} 15.0
```

**3. Verify Traces in Tempo**
```bash
# Create a task in UI, then check Grafana Explore
# Datasource: Tempo
# Query: Search for traces from service "flask-backend"
# Should see spans: POST /api/tasks → INSERT /app/data/tasks.db
```

**4. Verify Logs in Loki**
```bash
# Grafana Explore → Datasource: Loki
# Query: {service_name="flask-backend"} |= "Request completed"
# Should see logs with trace_id and span_id fields
```

**5. SLI Dashboard**
```bash
# Navigate to: http://192.168.122.250:3000/d/sli-slo-dashboard/
# After generating traffic:
#   - "Service Availability (SLI)" should show ~100% (if no errors)
#   - "Request Rate by Endpoint" should show non-zero lines
#   - "P95 Response Time" should show latency data
```

---

## Future Enhancements

### Short-Term (Next Sprint)

1. **Span Metrics from Tempo**
   - Enable `spanmetrics` in Tempo to generate RED metrics from traces
   - Provides automatic request/error/duration metrics without instrumentation

2. **Exemplars in Prometheus**
   - Link Prometheus metrics to Tempo traces
   - Click spike in graph → jump to example trace

3. **Custom Business Metrics**
   - Add `tasks_created_total`, `tasks_completed_total` counters
   - Track task lifecycle in dashboards

### Mid-Term (Future Releases)

1. **Alert Rules**
   - Define Prometheus alerting rules for SLO violations
   - Integrate with Alertmanager for notifications

2. **Service Mesh Integration**
   - If migrating to Kubernetes, integrate with Istio/Linkerd
   - Automatic service-to-service tracing

3. **Distributed Context Propagation**
   - Add frontend→backend trace propagation via W3C Trace Context headers
   - Full browser-to-database trace visualization

### Long-Term (Vision)

1. **Multi-Cluster Observability**
   - Centralized Grafana querying across dev/staging/prod clusters
   - Unified metrics/traces/logs view

2. **Machine Learning Integration**
   - Anomaly detection on latency/error metrics
   - Predictive SLO breach warnings

3. **Cost Optimization**
   - Implement trace sampling strategies
   - Metrics cardinality monitoring and reduction

---

## Summary

This observability architecture achieves:

✅ **Single Source of Truth** - Prometheus metrics come only from prometheus_client
✅ **Full Distributed Tracing** - OTel traces flow to Tempo with SQLAlchemy instrumentation
✅ **Correlated Logs** - Automatic trace_id injection enables log→trace navigation
✅ **Clean Separation** - OTel handles distributed context, Prometheus handles app metrics
✅ **No Duplication** - Eliminated double-counting and UID confusion
✅ **Production-Ready** - SLI/SLO dashboards work out-of-the-box
✅ **Environment-Agnostic** - Works seamlessly across localhost, VM, and cloud deployments

**Key Takeaway:**
By separating concerns (OTel for traces/logs, Prometheus client for metrics), we've built a maintainable, scalable observability stack that provides deep insights without architectural complexity.

---

**Document Version:** 1.0
**Authors:** Architecture designed collaboratively with Claude (Anthropic) and ChatGPT-5 (OpenAI)
**License:** MIT (adapt as needed for your organization)
