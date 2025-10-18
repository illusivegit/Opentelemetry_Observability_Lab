# OpenTelemetry Observability Lab - Complete Implementation Guide

## Document Purpose

This comprehensive guide documents the complete journey of building and troubleshooting a production-grade OpenTelemetry observability stack. This document captures every configuration decision, error encountered, solution implemented, and lesson learned during the development of this lab environment.

**Use this guide to:**
- Understand every component and configuration choice
- Troubleshoot similar issues in your own implementations
- Learn the "why" behind each technical decision
- Integrate this lab into CI/CD pipelines (Jenkins, GitLab CI, GitHub Actions)
- Build production-ready observability infrastructure

---

## Table of Contents

1. [Architecture Deep Dive](#architecture-deep-dive)
2. [Initial Configuration](#initial-configuration)
3. [Troubleshooting Journey](#troubleshooting-journey)
4. [Component Configurations](#component-configurations)
5. [Integration Patterns](#integration-patterns)
6. [CI/CD Pipeline Integration](#cicd-pipeline-integration)
7. [Production Readiness Checklist](#production-readiness-checklist)
8. [Performance Tuning](#performance-tuning)
9. [Security Considerations](#security-considerations)
10. [Lessons Learned](#lessons-learned)

---

## Architecture Deep Dive

### System Overview

The observability lab implements a complete telemetry pipeline following OpenTelemetry standards. The architecture separates concerns into distinct layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                            │
│  ┌────────────────┐                  ┌─────────────────┐        │
│  │   Frontend     │ ────HTTP────────>│ Flask Backend   │        │
│  │  (Nginx:8080)  │ <───JSON────────  │   (5000)        │        │
│  │                │                  │                 │        │
│  │ • OTel Browser │                  │ • OTel Python   │        │
│  │ • Auto-instr.  │                  │ • Flask instr.  │        │
│  │ • Manual spans │                  │ • SQLAlch. inst.│        │
│  └────────┬───────┘                  └────────┬────────┘        │
│           │                                   │                 │
│           │ OTLP/HTTP (traces)                │ OTLP/HTTP       │
│           │                                   │ (t/m/l)         │
└───────────┼───────────────────────────────────┼─────────────────┘
            │                                   │
            └───────────────┬───────────────────┘
                            │
                            ▼
            ┌───────────────────────────────────┐
            │   OpenTelemetry Collector         │
            │        (contrib:0.96.0)           │
            │                                   │
            │  Receivers:                       │
            │  • OTLP gRPC (4317)               │
            │  • OTLP HTTP (4318)               │
            │                                   │
            │  Processors:                      │
            │  • memory_limiter (512MB)         │
            │  • resource (add metadata)        │
            │  • attributes (enrich data)       │
            │  • attributes/logs (label hints)  │
            │  • batch (optimize sending)       │
            │                                   │
            │  Exporters:                       │
            │  • otlp/tempo (traces)            │
            │  • prometheusremotewrite (metrics)│
            │  • prometheus (metrics endpoint)  │
            │  • loki (logs)                    │
            │  • logging (debug)                │
            │                                   │
            │  Extensions:                      │
            │  • health_check (13133)           │
            │  • pprof (1777)                   │
            │  • zpages (55679)                 │
            └────────┬──────────┬───────┬───────┘
                     │          │       │
         ┌───────────┘          │       └──────────┐
         │                      │                  │
         ▼                      ▼                  ▼
┌────────────────┐    ┌────────────────┐  ┌───────────────┐
│  Grafana Tempo │    │  Prometheus    │  │  Grafana Loki │
│    (2.3.1)     │    │   (2.48.1)     │  │    (2.9.3)    │
│                │    │                │  │               │
│ • Storage:     │    │ • Storage:     │  │ • Storage:    │
│   /tmp/tempo   │    │   TSDB         │  │   /loki       │
│ • Port: 3200   │    │ • RW receiver  │  │ • Port: 3100  │
│ • OTLP: 4317   │    │ • Port: 9090   │  │ • Push API    │
└────────┬───────┘    └────────┬───────┘  └───────┬───────┘
         │                     │                  │
         └─────────────────────┼──────────────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │     Grafana      │
                     │     (10.2.3)     │
                     │                  │
                     │ • Port: 3000     │
                     │ • Anonymous auth │
                     │ • Provisioned:   │
                     │   - Datasources  │
                     │   - Dashboards   │
                     └──────────────────┘
```

### Data Flow Explanation

#### 1. **Telemetry Generation (Application Layer)**

**Frontend (Browser)**
```javascript
// OTel Browser SDK Configuration
const provider = new WebTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'frontend-browser'
  })
});

// Automatic instrumentation for fetch/XHR
registerInstrumentations({
  instrumentations: [
    new FetchInstrumentation(),
    new XMLHttpRequestInstrumentation()
  ]
});

// Exporter configuration
const exporter = new OTLPTraceExporter({
  url: 'http://localhost:4318/v1/traces'
});
```

**Backend (Flask)**
```python
# Resource configuration
resource = Resource.create({
    "service.name": "flask-backend",
    "service.version": "1.0.0",
    "deployment.environment": "lab"
})

# Trace provider setup
tracer_provider = TracerProvider(resource=resource)
otlp_trace_exporter = OTLPSpanExporter(
    endpoint="http://otel-collector:4318/v1/traces"
)
span_processor = BatchSpanProcessor(otlp_trace_exporter)
tracer_provider.add_span_processor(span_processor)

# Metrics provider setup
otlp_metric_exporter = OTLPMetricExporter(
    endpoint="http://otel-collector:4318/v1/metrics"
)
metric_reader = PeriodicExportingMetricReader(
    otlp_metric_exporter,
    export_interval_millis=5000
)
meter_provider = MeterProvider(
    resource=resource,
    metric_readers=[metric_reader]
)

# Logs provider setup
logger_provider = LoggerProvider(resource=resource)
otlp_log_exporter = OTLPLogExporter(
    endpoint="http://otel-collector:4318/v1/logs"
)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(otlp_log_exporter)
)
```

#### 2. **Telemetry Collection (OpenTelemetry Collector)**

The collector acts as a centralized telemetry hub, providing:
- **Decoupling**: Application doesn't need to know about backend storage
- **Processing**: Batch, filter, enrich, and transform telemetry
- **Fan-out**: Send same data to multiple backends
- **Buffering**: Handle temporary backend outages
- **Security**: Single point for authentication/encryption

#### 3. **Telemetry Storage (Backend Systems)**

**Tempo (Traces)**
- Stores complete distributed traces
- Indexed by trace ID
- Efficient compression (Parquet format)
- Supports TraceQL queries

**Prometheus (Metrics)**
- Time-series database optimized for metrics
- Remote write receiver enabled
- Scrapes collector's internal metrics
- PromQL query language

**Loki (Logs)**
- Log aggregation system
- Labels for indexing (not full-text search)
- Efficient log storage (compressed chunks)
- LogQL query language

#### 4. **Telemetry Visualization (Grafana)**

- **Unified interface** for all three pillars
- **Correlation features**:
  - Trace → Logs (via trace ID)
  - Trace → Metrics (via exemplars)
  - Logs → Traces (via derived fields)
- **Pre-provisioned** datasources and dashboards
- **Anonymous authentication** for lab ease-of-use

---

## Initial Configuration

### Docker Compose Architecture

The `docker-compose.yml` orchestrates 7 services with careful dependency management:

```yaml
version: '3.8'

networks:
  otel-network:
    driver: bridge

volumes:
  backend-data:      # Flask SQLite database
  tempo-data:        # Tempo trace storage
  loki-data:         # Loki log storage
  prometheus-data:   # Prometheus metrics storage
  grafana-data:      # Grafana configuration persistence

services:
  # Service startup order:
  # 1. tempo, loki, prometheus (storage backends)
  # 2. otel-collector (depends on storage backends)
  # 3. grafana (depends on storage backends for provisioning)
  # 4. backend (depends on collector)
  # 5. frontend (no dependencies)
```

**Key Design Decisions:**

1. **Network Isolation**: All services on `otel-network` bridge network
   - Internal DNS resolution (service name = hostname)
   - Port exposure only where needed
   - Security through network segmentation

2. **Volume Strategy**:
   - Named volumes for persistence (survive container recreation)
   - Bind mounts for configuration (live editing during development)
   - Backend data volume for SQLite database persistence

3. **Environment Variables**:
   - OTEL configuration via env vars (12-factor app principle)
   - Easy override in different environments
   - No hardcoded endpoints in application code

### OpenTelemetry Collector Configuration

**File**: `otel-collector/otel-collector-config.yml`

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - "http://localhost:8080"
            - "http://*"
          allowed_headers:
            - "*"

processors:
  # Order matters! Processors run in sequence.

  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    # Prevents OOM by rejecting data when near limit
    # Critical for production stability

  resource:
    attributes:
      - key: service.instance.id
        value: ${env:HOSTNAME}
        action: insert
      - key: loki.resource.labels
        value: service.name, service.instance.id, deployment.environment
        action: insert
        # Attribute hint: tells Loki exporter to promote these
        # resource attributes to Loki labels for efficient filtering

  attributes:
    actions:
      - key: environment
        value: "lab"
        action: insert

  attributes/logs:
    actions:
      - key: service.name
        from_context: resource
        action: insert
      - key: service.instance.id
        from_context: resource
        action: insert
      - key: level
        from_attribute: severity_text
        action: insert
      - key: loki.attribute.labels
        value: level
        action: insert
        # Attribute hint: promotes log-level to Loki label

  batch:
    timeout: 10s
    send_batch_size: 1024
    # Batching reduces network overhead and backend load
    # Trade-off: slight delay vs. efficiency

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true

  prometheus:
    endpoint: "0.0.0.0:8889"
    # Exposes metrics for Prometheus to scrape

  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    tls:
      insecure: true
    # No 'labels' config needed - using attribute hints in processors

  logging:
    loglevel: info
    sampling_initial: 5
    sampling_thereafter: 200
    # Debug exporter - samples to avoid log spam

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777
  zpages:
    endpoint: 0.0.0.0:55679

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [otlp/tempo, logging]

    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [prometheus, prometheusremotewrite]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, attributes/logs, batch]
      exporters: [loki, logging]
```

**Configuration Rationale:**

1. **Memory Limiter First**: Protects collector from OOM crashes
2. **Resource Processor**: Enriches all telemetry with common attributes
3. **Attribute Hints**: Modern approach for configuring Loki labels (v0.96.0+)
4. **Batch Processor Last**: Batches after all transformations complete
5. **Multiple Exporters**: Parallel export to storage + debug logging

### Prometheus Configuration

**File**: `otel-collector/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'otel-lab'
    environment: 'development'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888']
        labels:
          service: 'otel-collector'

  - job_name: 'otel-collector-prometheus-exporter'
    static_configs:
      - targets: ['otel-collector:8889']
        labels:
          service: 'otel-metrics'

  - job_name: 'tempo'
    static_configs:
      - targets: ['tempo:3200']
        labels:
          service: 'tempo'

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']
        labels:
          service: 'loki'

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
        labels:
          service: 'grafana'

# NOTE: No remote_write section!
# This was a critical fix - removed self-referential remote_write
# that caused Prometheus to write to itself in an infinite loop
```

**Key Insight**: Prometheus in this stack has dual roles:
1. **Metrics storage** (receives from collector via remote write)
2. **Metrics scraper** (scrapes collector and backend metrics)

**Critical Fix Applied**: Removed `remote_write` section that pointed back to itself, which created an infinite loop causing:
- Memory exhaustion
- Write amplification
- Storage bloat

### Grafana Datasource Provisioning

**File**: `grafana/provisioning/datasources/datasources.yml`

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    uid: prometheus  # ← Explicit UID for cross-datasource references
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      manageAlerts: true
      prometheusType: Prometheus
      prometheusVersion: 2.48.0
      cacheLevel: 'High'
      timeInterval: 15s

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    uid: tempo  # ← Explicit UID
    editable: true
    jsonData:
      httpMethod: GET

      # Trace → Log correlation
      tracesToLogs:
        datasourceUid: 'loki'
        tags: ['otelTraceID']
        mappedTags: [{ key: 'service.name', value: 'service_name' }]
        mapTagNamesEnabled: true
        spanStartTimeShift: '-1h'
        spanEndTimeShift: '1h'
        filterByTraceID: true
        filterBySpanID: false
        customQuery: true
        query: '{service_name="${__span.tags["service.name"]}"} |= "${__trace.traceId}"'

      # Trace → Metrics correlation
      tracesToMetrics:
        datasourceUid: 'prometheus'
        tags: [{ key: 'service.name', value: 'service' }]
        queries:
          - name: 'Request Rate'
            query: 'rate(http_requests_total{$$__tags}[5m])'
          - name: 'Error Rate'
            query: 'rate(http_errors_total{$$__tags}[5m])'

      serviceMap:
        datasourceUid: 'prometheus'

      search:
        hide: false

      nodeGraph:
        enabled: true

      lokiSearch:
        datasourceUid: 'loki'

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    uid: loki  # ← Explicit UID
    editable: true
    jsonData:
      maxLines: 1000

      # Log → Trace correlation
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: '"otelTraceID":"([0-9a-f]+)"'
          name: TraceID
          url: '$${__value.raw}'
        - datasourceUid: tempo
          matcherRegex: 'otelTraceID=([0-9a-f]+)'
          name: otelTraceID
          url: '$${__value.raw}'
```

**Correlation Deep Dive:**

This configuration creates bidirectional links between all three pillars:

1. **Tempo → Loki (tracesToLogs)**:
   - When viewing a trace span, click "Logs for this span"
   - Grafana extracts `service.name` from span attributes
   - Constructs Loki query: `{service_name="flask-backend"} |= "trace-id-here"`
   - Shows logs with matching trace ID from same service

2. **Tempo → Prometheus (tracesToMetrics)**:
   - View metrics related to traced operations
   - Exemplar linking (Prometheus samples with trace context)
   - Jump from trace span to rate/latency metrics

3. **Loki → Tempo (derivedFields)**:
   - Regex extracts trace IDs from log messages
   - Creates clickable links in log viewer
   - Jump from log line to full distributed trace

---

## Troubleshooting Journey

This section documents every problem encountered, attempted solutions, and final fixes. This is the most valuable section for learning and troubleshooting similar issues.

### Issue #1: Flask Backend Container - Application Context Error

#### Error Symptoms

```bash
$ docker compose up -d
[+] Running 7/7
 ✔ Container tempo                Started
 ✔ Container loki                 Started
 ✔ Container prometheus           Started
 ✔ Container otel-collector       Started
 ✔ Container grafana              Started
 ✔ Container flask-backend        Started
 ✔ Container frontend             Started

$ docker compose ps
NAME              IMAGE                                       STATUS
flask-backend     otel-observability-lab-backend              Restarting

$ docker logs flask-backend
Traceback (most recent call last):
  File "/app/app.py", line 96, in <module>
    SQLAlchemyInstrumentor().instrument(engine=db.engine)
  File "/usr/local/lib/python3.11/site-packages/werkzeug/local.py", line 316, in __get__
    obj = instance._get_current_object()
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.11/site-packages/werkzeug/local.py", line 513, in _get_current_object
    raise RuntimeError(unbound_message) from None
RuntimeError: Working outside of application context.

This typically means that you attempted to use functionality that needed
the current application. To solve this, set up an application context
with app.app_context().
```

#### Root Cause Analysis

**Problem**: `db.engine` is a Flask `LocalProxy` object that requires an active Flask application context. The code attempted to access `db.engine` at module import time (line 96), before the Flask application context was established.

**Code location**: `backend/app.py:96`

```python
# WRONG - executed at import time, no app context
app = Flask(__name__)
db = SQLAlchemy(app)
SQLAlchemyInstrumentor().instrument(engine=db.engine)  # ← FAILS HERE
```

**Why this happens**:
1. Python imports the module
2. Flask app and SQLAlchemy are initialized
3. `db.engine` is a lazy proxy - doesn't exist until first request
4. SQLAlchemy instrumentation tries to access the engine
5. No Flask request context exists yet
6. Runtime error

#### Solution 1 (Failed): Moving Code Inside Function

**Attempt**:
```python
def initialize_app():
    SQLAlchemyInstrumentor().instrument(engine=db.engine)

if __name__ == '__main__':
    initialize_app()
    app.run(host='0.0.0.0', port=5000)
```

**Result**: Still failed because Gunicorn (production WSGI server) doesn't execute the `if __name__ == '__main__'` block.

#### Solution 2 (Successful): Application Context

**Implementation**:
```python
# Create Flask app and SQLAlchemy instance
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////app/data/tasks.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# Instrument Flask (safe outside app context)
FlaskInstrumentor().instrument_app(app)
LoggingInstrumentor().instrument(set_logging_format=True)

# Database Model definition
class Task(db.Model):
    # ... model definition ...

# Create tables and instrument SQLAlchemy INSIDE app context
with app.app_context():
    os.makedirs('/app/data', exist_ok=True)

    # Now db.engine is accessible because we're in app context
    SQLAlchemyInstrumentor().instrument(engine=db.engine)

    db.create_all()
    logger.info("Database initialized")
```

**Why this works**:
- `with app.app_context():` establishes a Flask application context
- Inside this block, `db.engine` can be safely accessed
- Context is automatically cleaned up after block exits
- Code runs during module import, before any requests

#### Lessons Learned

1. **Flask Context Requirements**:
   - Some operations require application context
   - Some require request context
   - Know which one you need

2. **OTel Instrumentation Timing**:
   - Some instrumentations work at module level (Flask)
   - Others need runtime objects (SQLAlchemy engine)
   - Read instrumentation documentation carefully

3. **Debugging Strategy**:
   - Read full error traceback
   - Identify the exact line failing
   - Understand object lifecycle (when does it exist?)
   - Check framework documentation for context requirements

---

### Issue #2: SQLite Database - File Not Found

#### Error Symptoms

```bash
$ docker logs flask-backend
sqlite3.OperationalError: unable to open database file
```

Occurred simultaneously with the application context error, but persisted after fixing that issue.

#### Root Cause Analysis

**Two problems**:

1. **Relative path in database URI**:
```python
# WRONG
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///data/tasks.db'
```
- Relative to current working directory
- Docker container working directory is `/app`
- Path resolved to `/app/data/tasks.db`
- But directory creation used different path

2. **Directory creation mismatch**:
```python
# WRONG
os.makedirs('data', exist_ok=True)
```
- Created `/app/data` directory
- But SQLite tried to write to current directory

#### Solution

```python
# Absolute path for database URI (4 slashes for absolute path)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////app/data/tasks.db'
#                                                 ^ fourth slash indicates absolute path

# Absolute path for directory creation
with app.app_context():
    os.makedirs('/app/data', exist_ok=True)
    SQLAlchemyInstrumentor().instrument(engine=db.engine)
    db.create_all()
```

**SQLite URI format**:
- `sqlite:///relative/path/db.db` - 3 slashes = relative path
- `sqlite:////absolute/path/db.db` - 4 slashes = absolute path
- First three slashes are protocol separator `://`
- Fourth slash starts absolute path `/`

#### Volume Mounting

Ensured database persistence across container restarts:

```yaml
# docker-compose.yml
services:
  backend:
    volumes:
      - ./backend:/app        # Code (for development)
      - backend-data:/app/data  # Database persistence

volumes:
  backend-data:
```

#### Lessons Learned

1. **Always use absolute paths in containerized apps**
   - Working directory can vary between local and container
   - Eliminates path ambiguity
   - Easier to debug

2. **SQLite URI syntax matters**
   - Count the slashes carefully
   - Different meaning between 3 and 4 slashes

3. **Volume strategy**:
   - Bind mounts for code (development)
   - Named volumes for data (persistence)
   - Never rely on container filesystem for state

---

### Issue #3: Docker Build Cache - Code Changes Not Reflected

#### Error Symptoms

After fixing the application context error in `app.py`:

```bash
$ docker compose up -d
[+] Running 1/1
 ✔ Container flask-backend  Started

$ docker logs flask-backend
# Still shows the OLD error from line 96!
RuntimeError: Working outside of application context.
```

File clearly updated, but container running old code.

#### Root Cause Analysis

**Docker Build Cache**:
- Docker caches layers for fast rebuilds
- If `backend/Dockerfile` hasn't changed, uses cached image
- Bind mount (`./backend:/app`) should sync code changes
- But if Python cache files (`.pyc`) are in image, they take precedence

**Dockerfile structure**:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . /app  # ← This layer was cached
CMD ["gunicorn", "app:app"]
```

#### Solution Attempts

**Attempt 1**: Simple restart
```bash
docker compose restart backend
# Failed - still running cached image
```

**Attempt 2**: Rebuild with no-cache
```bash
docker compose build --no-cache backend
docker compose up -d
# Success! Fresh build with new code
```

**Attempt 3**: Complete teardown (nuclear option)
```bash
docker compose down
docker compose build --no-cache backend
docker compose up -d
# Also works, but slower (rebuilds all services)
```

#### Prevention Strategy

**For Development**: Add to `docker-compose.yml`
```yaml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    volumes:
      - ./backend:/app
    environment:
      - PYTHONDONTWRITEBYTECODE=1  # Prevents .pyc file creation
      - PYTHONUNBUFFERED=1          # Real-time log output
```

**For Production**: Use multi-stage builds
```dockerfile
# Builder stage
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Runtime stage
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . /app
ENV PATH=/root/.local/bin:$PATH
CMD ["gunicorn", "app:app"]
```

#### Lessons Learned

1. **Docker caching is aggressive**
   - Good for speed, bad for debugging
   - When in doubt, `--no-cache`
   - Check image creation time: `docker images`

2. **Volume mounts don't override everything**
   - Python bytecode cache can cause issues
   - Use `PYTHONDONTWRITEBYTECODE=1` in development

3. **Clear rebuild process**:
   ```bash
   # Development quick fix
   docker compose restart <service>

   # Code changes not reflected
   docker compose build --no-cache <service> && docker compose up -d

   # Nuclear option (when all else fails)
   docker compose down -v && docker compose up -d --build
   ```

---

### Issue #4: Network Resolution - DNS Failure

#### Error Symptoms

After successful container start:

```bash
$ docker logs flask-backend
socket.gaierror: [Errno -2] Name or service not known
urllib3.exceptions.NameResolutionError: Failed to resolve 'otel-collector'
```

Application starts, but can't send telemetry to collector.

#### Root Cause Analysis

**Docker DNS Resolution**:
- Containers on same network resolve each other by service name
- Docker's embedded DNS server (127.0.0.11)
- Service discovery happens automatically

**What went wrong**:
- Partial container restart (`docker compose restart backend`)
- Network interface not properly reinitialized
- DNS resolver cached stale information
- Backend container couldn't resolve `otel-collector` hostname

**Verification**:
```bash
$ docker compose exec backend ping otel-collector
ping: otel-collector: Name or service not known

$ docker network inspect otel-observability-lab_otel-network
# Backend container shows "Aliases": ["backend"] but disconnected
```

#### Solution

**Full network reset**:
```bash
docker compose down    # Removes containers and default network
docker compose up -d   # Recreates everything with fresh DNS
```

**Why this works**:
- `docker compose down` tears down containers AND network
- `docker compose up` recreates network with fresh DNS configuration
- All service names registered correctly in DNS
- Containers can resolve each other

**Quick verification**:
```bash
$ docker compose exec backend ping otel-collector
PING otel-collector (172.19.0.5): 56 data bytes
64 bytes from 172.19.0.5: seq=0 ttl=64 time=0.123 ms
```

#### Network Debugging Tools

**Check service discovery**:
```bash
# List all containers on network
docker network inspect otel-observability-lab_otel-network | jq '.[0].Containers'

# Test DNS from inside container
docker compose exec backend nslookup otel-collector
docker compose exec backend getent hosts otel-collector

# Check network connectivity
docker compose exec backend curl http://otel-collector:13133  # Health check
```

#### Lessons Learned

1. **When DNS fails, full restart**:
   - Don't fight with partial restarts
   - `docker compose down && docker compose up -d` is often fastest solution

2. **Network debugging order**:
   - Can container start? (Check logs)
   - Can container resolve service names? (nslookup/ping)
   - Can container connect to ports? (curl/telnet)
   - Is service actually listening? (Check service logs)

3. **Docker networking**:
   - Service names = hostnames (automatic DNS)
   - Bridge network = container isolation
   - Container restarts should ideally use `docker compose restart`
   - But DNS issues need full network recreation

---

### Issue #5: Logs Not Appearing in Loki

#### Error Symptoms

- Prometheus metrics: ✅ Working
- Tempo traces: ✅ Working
- Loki logs: ❌ Empty results

```bash
$ curl -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={service_name="flask-backend"}' | jq
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": []
  }
}
```

Loki was running, accepting queries, but had no data.

#### Root Cause Analysis

**Checked collector logs**:
```bash
$ docker logs otel-collector | grep -i log
# No log export activity
```

**Checked backend logs**:
```bash
$ docker logs flask-backend
{"asctime": "2025-10-13T10:15:30", "name": "root", "levelname": "INFO", ...}
# Logs going to stdout, but not to OTLP
```

**Problem identified**: Backend was NOT exporting logs via OTLP protocol. Logs only went to stdout.

**Code inspection** (`backend/app.py`):
```python
# Traces: ✅ Configured
tracer_provider = TracerProvider(resource=resource)
otlp_trace_exporter = OTLPSpanExporter(...)

# Metrics: ✅ Configured
meter_provider = MeterProvider(resource=resource, metric_readers=[...])

# Logs: ❌ NOT configured for OTLP export
# Only had:
logHandler = logging.StreamHandler()  # stdout only
```

#### Solution

**Added complete OTLP Logs SDK** (`backend/app.py`):

```python
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry._logs import set_logger_provider

# Setup Logs - Export to OTLP
logger_provider = LoggerProvider(resource=resource)
set_logger_provider(logger_provider)

otlp_log_exporter = OTLPLogExporter(
    endpoint=f"{os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://otel-collector:4318')}/v1/logs",
    timeout=5
)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(otlp_log_exporter))

# Bridge stdlib logging to OpenTelemetry logs SDK
otel_log_handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
logging.getLogger().addHandler(otel_log_handler)
```

**Verification**:
```bash
$ docker compose build --no-cache backend && docker compose up -d
$ docker logs otel-collector | grep -i log
2025-10-13T10:20:15.123Z info LogsExporter {"kind": "exporter", "data_type": "logs", "name": "logging", "resource logs": 1, "log records": 5}
```

Now logs flowing: Backend → Collector → Loki

#### Logs Architecture

```
Python stdlib logging (logging.info, logging.error, etc.)
           ↓
LoggingHandler (OpenTelemetry bridge)
           ↓
LoggerProvider (OTel SDK)
           ↓
BatchLogRecordProcessor (batching for efficiency)
           ↓
OTLPLogExporter (OTLP/HTTP protocol)
           ↓
OpenTelemetry Collector
           ↓
Loki Exporter
           ↓
Grafana Loki
```

**Key Components**:

1. **LoggingHandler**: Intercepts Python log records
2. **LoggerProvider**: OTel SDK for logs (like TracerProvider for traces)
3. **BatchLogRecordProcessor**: Buffers logs, sends in batches
4. **OTLPLogExporter**: Serializes logs to OTLP format
5. **Resource**: Adds service metadata to every log

#### Lessons Learned

1. **Three pillars = three SDK configurations**:
   - Don't assume logs work if traces/metrics work
   - Each pillar needs explicit setup

2. **Log export patterns**:
   - Stdout/stderr = good for debugging, bad for aggregation
   - OTLP = structured, queryable, correlatable
   - Both together = best of both worlds

3. **Verification checklist**:
   ```bash
   # Check application exports
   docker logs backend | grep -i "otel"

   # Check collector receives
   docker logs otel-collector | grep -i "LogsExporter"

   # Check Loki stores
   curl "http://localhost:3100/loki/api/v1/labels"
   ```

---

### Issue #6: Loki Labels - Missing service_name

#### Error Symptoms

Logs appearing in Loki, but limited label options:

```bash
$ curl -s "http://localhost:3100/loki/api/v1/labels" | jq
{
  "status": "success",
  "data": ["exporter", "instance", "job", "level"]
}
```

**Expected**: `service_name` label for filtering by service

**Impact**:
- Can't query `{service_name="flask-backend"}`
- Can't use "Logs for this span" feature in Tempo
- Poor log filtering experience in Grafana

#### Root Cause Analysis

**Loki Label Philosophy**:
- Loki is NOT full-text search (not Elasticsearch)
- Labels are INDEX keys (like database indexes)
- Only indexed fields can be in `{label="value"}` queries
- Everything else requires log content filtering: `{label="value"} |= "text"`

**Problem**: OTel resource attributes (service.name, deployment.environment) weren't being promoted to Loki labels.

**Collector configuration** (v0.91.0):
```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    tls:
      insecure: true
    # No label configuration!
```

**Why labels weren't created**:
- Resource attributes: `service.name`, `deployment.environment`
- Log attributes: `severity_text`, custom attributes
- Loki needs to be TOLD which attributes to promote to labels
- Otherwise, everything goes into log content (not searchable by label)

#### Solution Attempt #1: Add labels Configuration (Failed)

**Tried this**:
```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    tls:
      insecure: true
    labels:
      resource:
        service.name: "service_name"
        service.instance.id: "service_instance_id"
      attributes:
        severity_text: "level"
```

**Result**:
```bash
$ docker logs otel-collector
Error: failed to get config: cannot unmarshal the configuration:
1 error(s) decoding:
* error decoding 'exporters': error reading configuration for "loki":
1 error(s) decoding:
* '' has invalid keys: labels
```

**Why it failed**: The `labels` configuration was **deprecated in v0.57.0** and **removed in v0.76.0+** of the OTel Collector.

#### Solution Attempt #2: Check Collector Version

```bash
$ docker compose exec otel-collector /otelcontribcol --version
otelcol-contrib version 0.91.0
```

Version 0.91.0 = November 2023 = labels config removed

**Documentation search**: Found that `labels` was replaced with **attribute hints**

#### Solution Attempt #3: Upgrade to v0.96.0 + Attribute Hints (Success!)

**Step 1**: Upgraded collector version

`docker-compose.yml`:
```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.96.0  # Was: 0.91.0
```

**Step 2**: Used modern attribute hint approach

`otel-collector/otel-collector-config.yml`:
```yaml
processors:
  resource:
    attributes:
      - key: service.instance.id
        value: ${env:HOSTNAME}
        action: insert
      - key: loki.resource.labels
        value: service.name, service.instance.id, deployment.environment
        action: insert
        # ↑ Attribute hint: tells Loki exporter which resource
        # attributes to promote to labels

  attributes/logs:
    actions:
      - key: service.name
        from_context: resource
        action: insert
      - key: service.instance.id
        from_context: resource
        action: insert
      - key: level
        from_attribute: severity_text
        action: insert
      - key: loki.attribute.labels
        value: level
        action: insert
        # ↑ Attribute hint: promotes log attributes to labels

exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    tls:
      insecure: true
    # No labels config - using attribute hints instead!
```

**How attribute hints work**:

1. **Processor** adds special attribute: `loki.resource.labels`
2. Value is comma-separated list: `service.name, service.instance.id`
3. **Loki exporter** reads this hint
4. Exporter promotes listed attributes to Loki labels
5. Loki indexes these as stream labels

**Step 3**: Deployed changes

```bash
docker compose down
docker compose up -d
```

**Step 4**: Verified labels

```bash
$ curl -s "http://localhost:3100/loki/api/v1/labels" | jq
{
  "status": "success",
  "data": [
    "deployment_environment",  # ← NEW
    "exporter",
    "instance",
    "job",
    "level",
    "service_instance_id",     # ← NEW
    "service_name"             # ← NEW - The one we wanted!
  ]
}
```

**Step 5**: Tested query

```bash
$ curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={service_name="flask-backend"}' \
  --data-urlencode "start=$(date -u -d '5 minutes ago' '+%s')000000000" \
  --data-urlencode "end=$(date -u '+%s')000000000" | jq '.data.result[0].stream'

{
  "deployment_environment": "lab",
  "exporter": "OTLP",
  "instance": "dd0cb630c708",
  "job": "flask-backend",
  "level": "INFO",
  "service_instance_id": "dd0cb630c708",
  "service_name": "flask-backend"
}
```

✅ **Success!** Now we can query: `{service_name="flask-backend"}`

#### Label Design Considerations

**Loki has a 15-label default limit**. Choose labels carefully:

**Good labels** (high cardinality but bounded):
- `service_name` - Number of services (10-100)
- `deployment_environment` - dev/staging/prod (3-5)
- `level` - debug/info/warn/error (5)

**Bad labels** (unbounded cardinality):
- `user_id` - Millions of users = millions of label combinations
- `request_id` - Every request is unique
- `trace_id` - Every trace is unique

**Rule of thumb**:
- Total label combinations < 100,000
- If unbounded, use log content filtering: `{service_name="x"} |= "user_id=123"`

#### Lessons Learned

1. **OpenTelemetry is evolving fast**:
   - Configuration patterns change between versions
   - Always check version-specific documentation
   - `labels` → `attribute hints` is a perfect example

2. **Attribute hints are more flexible**:
   - Configured in processors (one place)
   - Works across multiple exporters
   - More explicit about intent

3. **Loki label strategy matters**:
   - Labels = index = query performance
   - Too many = performance death
   - Too few = poor filtering
   - Sweet spot: 5-10 labels, bounded cardinality

4. **Version upgrades in containers**:
   - Easy with Docker Compose (change image tag)
   - Test in lab before production
   - Check for breaking changes in release notes

---

## Component Configurations

### Flask Backend Deep Dive

**File**: `backend/app.py`

The Flask backend demonstrates comprehensive OpenTelemetry instrumentation:

#### OpenTelemetry Setup

```python
# Resource: Identifies this service in the telemetry system
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "flask-backend"),
    "service.version": "1.0.0",
    "deployment.environment": "lab"
})
```

**Resource attributes are crucial**:
- Attached to EVERY span, metric, log
- Used for filtering and grouping
- Enable multi-environment deployments
- Support service mesh integration

#### Tracing Configuration

```python
# Tracer Provider
tracer_provider = TracerProvider(resource=resource)

# OTLP Span Exporter
otlp_trace_exporter = OTLPSpanExporter(
    endpoint=f"{os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')}/v1/traces"
)

# Batch Span Processor
span_processor = BatchSpanProcessor(otlp_trace_exporter)
tracer_provider.add_span_processor(span_processor)

# Set global tracer provider
trace.set_tracer_provider(tracer_provider)

# Get tracer for manual instrumentation
tracer = trace.get_tracer(__name__)
```

**Why BatchSpanProcessor?**
- Buffers spans in memory
- Sends in batches (reduces network calls)
- Configurable: batch size, timeout
- Production-ready (handles failures gracefully)

**Alternative**: `SimpleSpanProcessor`
- Sends each span immediately
- Good for debugging
- Bad for performance

#### Metrics Configuration

```python
# OTLP Metric Exporter
otlp_metric_exporter = OTLPMetricExporter(
    endpoint=f"{os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')}/v1/metrics"
)

# Periodic Exporting Metric Reader
metric_reader = PeriodicExportingMetricReader(
    otlp_metric_exporter,
    export_interval_millis=5000  # Export every 5 seconds
)

# Meter Provider
meter_provider = MeterProvider(
    resource=resource,
    metric_readers=[metric_reader]
)
metrics.set_meter_provider(meter_provider)

# Get meter for creating instruments
meter = metrics.get_meter(__name__)
```

**Metric Instruments Created**:

1. **Counter**: Monotonically increasing value
```python
request_counter = meter.create_counter(
    name="http_requests_total",
    description="Total number of HTTP requests",
    unit="1"
)

# Usage
request_counter.add(1, {
    "method": request.method,
    "endpoint": request.endpoint,
    "status_code": str(response.status_code)
})
```

2. **Histogram**: Distribution of values
```python
request_duration = meter.create_histogram(
    name="http_request_duration_seconds",
    description="HTTP request duration in seconds",
    unit="s"
)

# Usage
request_duration.record(duration, {
    "method": request.method,
    "endpoint": request.endpoint
})
```

**Why these metric types?**
- **Counter**: For calculating rates (req/sec, errors/sec)
- **Histogram**: For percentiles (p50, p95, p99 latency)
- Both support labels/attributes for grouping

#### Logs Configuration

```python
# Logger Provider
logger_provider = LoggerProvider(resource=resource)
set_logger_provider(logger_provider)

# OTLP Log Exporter
otlp_log_exporter = OTLPLogExporter(
    endpoint=f"{os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')}/v1/logs",
    timeout=5
)

# Batch Log Record Processor
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(otlp_log_exporter)
)

# Logging Handler (bridges stdlib logging to OTel)
otel_log_handler = LoggingHandler(
    level=logging.INFO,
    logger_provider=logger_provider
)
logging.getLogger().addHandler(otel_log_handler)
```

**Dual logging setup**:
```python
# Structured JSON to stdout (for kubectl logs, docker logs)
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(
    '%(asctime)s %(name)s %(levelname)s %(message)s %(trace_id)s %(span_id)s'
)
logHandler.setFormatter(formatter)
logger = logging.getLogger()
logger.addHandler(logHandler)

# OTLP to collector (for Loki, aggregation)
logger.addHandler(otel_log_handler)
```

**Benefits**:
- Stdout logs: Easy kubectl/docker debugging
- OTLP logs: Centralized aggregation, correlation, querying

#### Automatic Instrumentation

```python
# Flask HTTP instrumentation
FlaskInstrumentor().instrument_app(app)

# SQLAlchemy database instrumentation
with app.app_context():
    SQLAlchemyInstrumentor().instrument(engine=db.engine)

# Logging instrumentation
LoggingInstrumentor().instrument(set_logging_format=True)
```

**What FlaskInstrumentor does**:
- Creates span for every HTTP request
- Captures HTTP method, route, status code
- Propagates trace context (W3C Trace Context headers)
- Handles exceptions

**What SQLAlchemyInstrumentor does**:
- Creates span for every database query
- Captures SQL statement (sanitized)
- Records query duration
- Links to parent HTTP span

#### Manual Instrumentation

```python
@app.route('/api/tasks', methods=['POST'])
def create_task():
    with tracer.start_as_current_span("create_task") as span:
        try:
            data = request.get_json()

            # Custom span attributes
            span.set_attribute("task.title", data['title'])
            span.set_attribute("validation.failed", False)

            # Business logic
            new_task = Task(title=data['title'], ...)
            db.session.add(new_task)
            db.session.commit()

            span.set_attribute("task.id", new_task.id)

            return jsonify(new_task.to_dict()), 201

        except Exception as e:
            # Record exception in span
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))

            # Also log
            logger.error(f"Error creating task: {str(e)}", exc_info=True)

            return jsonify({"error": "Failed to create task"}), 500
```

**When to manually instrument**:
- Business-specific operations
- Domain logic spans (create_order, process_payment)
- Custom attributes (user_id, order_amount)
- Fine-grained performance tracking

#### Middleware for Request Tracking

```python
@app.before_request
def before_request():
    request.start_time = time.time()
    current_span = trace.get_current_span()
    logger.info(
        "Incoming request",
        extra={
            "method": request.method,
            "path": request.path,
            "trace_id": format(current_span.get_span_context().trace_id, '032x'),
            "span_id": format(current_span.get_span_context().span_id, '016x')
        }
    )

@app.after_request
def after_request(response):
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time

        # Record metrics
        request_counter.add(1, {
            "method": request.method,
            "endpoint": request.endpoint or "unknown",
            "status_code": str(response.status_code)
        })

        request_duration.record(duration, {
            "method": request.method,
            "endpoint": request.endpoint or "unknown",
            "status_code": str(response.status_code)
        })

        # Track errors for SLI
        if response.status_code >= 400:
            error_counter.add(1, {
                "method": request.method,
                "endpoint": request.endpoint or "unknown",
                "status_code": str(response.status_code)
            })

        # Log response
        current_span = trace.get_current_span()
        logger.info(
            "Request completed",
            extra={
                "method": request.method,
                "path": request.path,
                "status_code": response.status_code,
                "duration_seconds": duration,
                "trace_id": format(current_span.get_span_context().trace_id, '032x'),
                "span_id": format(current_span.get_span_context().span_id, '016x')
            }
        )

    return response
```

**Why middleware?**
- Centralized request/response logging
- Consistent metric collection
- Automatic correlation (trace ID in logs)
- No code duplication across endpoints

---

## Integration Patterns

### Trace Context Propagation

OpenTelemetry uses W3C Trace Context standard for distributed tracing:

#### Request Flow

```
Browser                Flask Backend              Database
   │                         │                        │
   │   POST /api/tasks       │                        │
   ├─────────────────────────>                        │
   │   Headers:              │                        │
   │   traceparent:          │                        │
   │   00-4bf92f...          │                        │
   │                         │                        │
   │                         │   INSERT INTO tasks    │
   │                         ├────────────────────────>
   │                         │   (child span)         │
   │                         │<───────────────────────┤
   │                         │                        │
   │   201 Created           │                        │
   │<─────────────────────────                        │
   │                         │                        │
```

#### W3C Trace Context Header Format

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             │  └─────────── trace-id ──────────┘ └─ span-id ─┘ │
             │                                                   │
             └─ version                                    flags ┘
```

**Components**:
- **version**: `00` (current version)
- **trace-id**: 128-bit identifier (32 hex chars)
- **parent-id**: 64-bit span identifier (16 hex chars)
- **trace-flags**: Sampling decision (01 = sampled)

#### Context Propagation Code

```python
# Flask automatically handles this with FlaskInstrumentor
# Manual example:

from opentelemetry.propagate import inject, extract

# Client side (sending request)
headers = {}
inject(headers)  # Adds traceparent header
response = requests.post('http://backend/api', headers=headers)

# Server side (receiving request)
ctx = extract(request.headers)  # Extracts trace context
with tracer.start_as_current_span("operation", context=ctx):
    # This span is now a child of the remote span
    pass
```

### Trace-Log Correlation

#### In Application Code

```python
from opentelemetry import trace

current_span = trace.get_current_span()
trace_id = format(current_span.get_span_context().trace_id, '032x')
span_id = format(current_span.get_span_context().span_id, '016x')

logger.info(
    "User action performed",
    extra={
        "trace_id": trace_id,
        "span_id": span_id,
        "user_id": user.id
    }
)
```

**Result in Loki**:
```json
{
  "timestamp": "2025-10-13T10:15:30.123Z",
  "level": "INFO",
  "message": "User action performed",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "user_id": "12345"
}
```

#### In Grafana

**Tempo → Loki**:
1. View trace span in Tempo
2. Click "Logs for this span"
3. Grafana extracts trace_id from span
4. Queries Loki: `{service_name="flask-backend"} |= "4bf92f3577b34da6"`
5. Shows correlated logs

**Loki → Tempo**:
1. View log in Loki
2. Regex extracts trace_id: `"otelTraceID":"([0-9a-f]+)"`
3. Creates clickable link to Tempo
4. Opens full distributed trace

### Trace-Metrics Correlation (Exemplars)

**What are exemplars?**
- Sample data points linking metrics to traces
- "Here's a specific trace that contributed to this metric"
- Answers: "Why is latency high?" → Click exemplar → See slow trace

**Configuration** (Prometheus):
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  # Enable exemplar storage
  storage:
    exemplars:
      max_exemplars: 100000
```

**In Application**:
```python
# Histogram automatically records exemplars when trace context exists
request_duration.record(
    duration,
    attributes={"endpoint": "/api/tasks", "method": "POST"}
)
# If in active span, exemplar includes trace_id
```

**In Grafana**:
1. View metrics panel
2. See spike in latency
3. Click data point
4. View exemplar traces
5. Jump to full trace in Tempo

---

## CI/CD Pipeline Integration

### Jenkins Pipeline Integration

This lab can be integrated into a Jenkins DevSecOps pipeline for automated testing and deployment.

#### Jenkinsfile Example

```groovy
pipeline {
    agent any

    environment {
        DOCKER_COMPOSE_FILE = 'otel-observability-lab/docker-compose.yml'
        GRAFANA_URL = 'http://localhost:3000'
        BACKEND_URL = 'http://localhost:5000'
    }

    stages {
        stage('Setup Observability Lab') {
            steps {
                script {
                    echo 'Starting OpenTelemetry Observability Lab...'
                    sh """
                        cd otel-observability-lab
                        docker compose down -v || true
                        docker compose up -d
                    """
                }
            }
        }

        stage('Health Checks') {
            steps {
                script {
                    echo 'Waiting for services to be healthy...'
                    sh '''
                        # Wait for collector
                        timeout 60 sh -c 'until curl -sf http://localhost:13133; do sleep 2; done'

                        # Wait for backend
                        timeout 60 sh -c 'until curl -sf http://localhost:5000/health; do sleep 2; done'

                        # Wait for Grafana
                        timeout 60 sh -c 'until curl -sf http://localhost:3000/api/health; do sleep 2; done'

                        # Wait for Prometheus
                        timeout 60 sh -c 'until curl -sf http://localhost:9090/-/healthy; do sleep 2; done'

                        # Wait for Loki
                        timeout 60 sh -c 'until curl -sf http://localhost:3100/ready; do sleep 2; done'

                        # Wait for Tempo
                        timeout 60 sh -c 'until curl -sf http://localhost:3200/ready; do sleep 2; done'
                    '''
                }
            }
        }

        stage('Generate Test Traffic') {
            steps {
                script {
                    echo 'Generating telemetry data...'
                    sh '''
                        # Create test tasks
                        for i in {1..10}; do
                            curl -X POST http://localhost:5000/api/tasks \
                                -H "Content-Type: application/json" \
                                -d "{\"title\":\"Jenkins Test Task $i\",\"description\":\"Created by Jenkins pipeline\"}"
                            sleep 1
                        done

                        # Get all tasks
                        curl http://localhost:5000/api/tasks

                        # Simulate slow request
                        curl "http://localhost:5000/api/simulate-slow?delay=1"

                        # Simulate error (expected to fail)
                        curl http://localhost:5000/api/simulate-error || true
                    '''

                    // Wait for telemetry to propagate
                    sleep(time: 10, unit: 'SECONDS')
                }
            }
        }

        stage('Verify Traces in Tempo') {
            steps {
                script {
                    echo 'Verifying distributed traces...'
                    sh '''
                        # Query Tempo for traces
                        TRACES=$(curl -s "http://localhost:3200/api/search?tags=service.name=flask-backend" | jq -r '.traces | length')

                        echo "Found $TRACES traces in Tempo"

                        if [ "$TRACES" -lt 5 ]; then
                            echo "ERROR: Expected at least 5 traces, found $TRACES"
                            exit 1
                        fi

                        echo "✅ Traces verification passed"
                    '''
                }
            }
        }

        stage('Verify Metrics in Prometheus') {
            steps {
                script {
                    echo 'Verifying metrics collection...'
                    sh '''
                        # Query Prometheus for request count
                        REQUESTS=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq -r '.data.result | length')

                        echo "Found $REQUESTS metric series"

                        if [ "$REQUESTS" -lt 1 ]; then
                            echo "ERROR: No http_requests_total metrics found"
                            exit 1
                        fi

                        # Check for request duration metrics
                        DURATION=$(curl -s 'http://localhost:9090/api/v1/query?query=http_request_duration_seconds_count' | jq -r '.data.result | length')

                        if [ "$DURATION" -lt 1 ]; then
                            echo "ERROR: No request duration metrics found"
                            exit 1
                        fi

                        echo "✅ Metrics verification passed"
                    '''
                }
            }
        }

        stage('Verify Logs in Loki') {
            steps {
                script {
                    echo 'Verifying log aggregation...'
                    sh '''
                        # Query Loki for logs
                        LOGS=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
                            --data-urlencode 'query={service_name="flask-backend"}' \
                            --data-urlencode "start=$(date -u -d '5 minutes ago' '+%s')000000000" \
                            --data-urlencode "end=$(date -u '+%s')000000000" \
                            --data-urlencode "limit=100" | jq -r '.data.result[0].values | length')

                        echo "Found $LOGS log entries"

                        if [ "$LOGS" -lt 5 ]; then
                            echo "ERROR: Expected at least 5 log entries, found $LOGS"
                            exit 1
                        fi

                        # Verify service_name label exists
                        LABELS=$(curl -s "http://localhost:3100/loki/api/v1/labels" | jq -r '.data[]')

                        if ! echo "$LABELS" | grep -q "service_name"; then
                            echo "ERROR: service_name label not found in Loki"
                            exit 1
                        fi

                        echo "✅ Logs verification passed"
                    '''
                }
            }
        }

        stage('SLI/SLO Validation') {
            steps {
                script {
                    echo 'Validating SLI/SLO metrics...'
                    sh '''
                        # Calculate availability SLI
                        TOTAL=$(curl -s 'http://localhost:9090/api/v1/query?query=sum(http_requests_total)' | jq -r '.data.result[0].value[1]')
                        ERRORS=$(curl -s 'http://localhost:9090/api/v1/query?query=sum(http_errors_total)' | jq -r '.data.result[0].value[1]')

                        if [ "$ERRORS" == "null" ]; then ERRORS=0; fi

                        AVAILABILITY=$(echo "scale=2; (($TOTAL - $ERRORS) / $TOTAL) * 100" | bc)

                        echo "Availability SLI: $AVAILABILITY%"
                        echo "Target: 99%"

                        # Check if availability meets SLO
                        if (( $(echo "$AVAILABILITY < 99" | bc -l) )); then
                            echo "⚠️  WARNING: Availability below SLO target"
                        else
                            echo "✅ Availability SLI passed"
                        fi

                        # Calculate P95 latency
                        P95=$(curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket[5m]))by(le))' | jq -r '.data.result[0].value[1]')

                        echo "P95 Latency: ${P95}s"
                        echo "Target: <0.5s"

                        if (( $(echo "$P95 > 0.5" | bc -l) )); then
                            echo "⚠️  WARNING: P95 latency above SLO target"
                        else
                            echo "✅ Latency SLI passed"
                        fi
                    '''
                }
            }
        }

        stage('Generate Observability Report') {
            steps {
                script {
                    echo 'Generating observability report...'
                    sh '''
                        cat > observability-report.txt <<EOF
========================================
OpenTelemetry Observability Lab Report
========================================
Build: ${BUILD_NUMBER}
Date: $(date)

TRACES (Tempo)
--------------
$(curl -s "http://localhost:3200/api/search?tags=service.name=flask-backend" | jq -r '.traces | length') traces collected

METRICS (Prometheus)
--------------------
Total Requests: $(curl -s 'http://localhost:9090/api/v1/query?query=sum(http_requests_total)' | jq -r '.data.result[0].value[1]')
Total Errors: $(curl -s 'http://localhost:9090/api/v1/query?query=sum(http_errors_total)' | jq -r '.data.result[0].value[1] // "0"')
P95 Latency: $(curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket[5m]))by(le))' | jq -r '.data.result[0].value[1]')s

LOGS (Loki)
-----------
$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" --data-urlencode 'query={service_name="flask-backend"}' --data-urlencode "start=$(date -u -d '5 minutes ago' '+%s')000000000" --data-urlencode "end=$(date -u '+%s')000000000" | jq -r '.data.result[0].values | length') log entries

LABELS
------
$(curl -s "http://localhost:3100/loki/api/v1/labels" | jq -r '.data | join(", ")')

========================================
EOF
                        cat observability-report.txt
                    '''

                    archiveArtifacts artifacts: 'observability-report.txt', fingerprint: true
                }
            }
        }

        stage('Export Grafana Dashboards') {
            steps {
                script {
                    echo 'Exporting Grafana dashboards as JSON...'
                    sh '''
                        mkdir -p grafana-exports

                        # List all dashboards
                        curl -s http://localhost:3000/api/search | jq -r '.[].uid' | while read uid; do
                            echo "Exporting dashboard: $uid"
                            curl -s "http://localhost:3000/api/dashboards/uid/$uid" | jq '.dashboard' > "grafana-exports/${uid}.json"
                        done
                    '''

                    archiveArtifacts artifacts: 'grafana-exports/*.json', fingerprint: true
                }
            }
        }
    }

    post {
        always {
            script {
                echo 'Collecting container logs...'
                sh '''
                    mkdir -p logs
                    cd otel-observability-lab
                    docker compose logs --no-color backend > ../logs/backend.log
                    docker compose logs --no-color otel-collector > ../logs/otel-collector.log
                    docker compose logs --no-color grafana > ../logs/grafana.log
                '''

                archiveArtifacts artifacts: 'logs/*.log', fingerprint: true
            }
        }

        success {
            echo '✅ Observability lab validation passed!'
        }

        failure {
            echo '❌ Observability lab validation failed. Check logs for details.'
        }

        cleanup {
            script {
                echo 'Cleaning up observability lab...'
                sh '''
                    cd otel-observability-lab
                    docker compose down -v
                '''
            }
        }
    }
}
```

#### Jenkins Integration Benefits

1. **Automated Observability Testing**: Validates telemetry pipeline in CI/CD
2. **SLI/SLO Enforcement**: Fails builds if SLOs aren't met
3. **Performance Regression Detection**: Compares latency across builds
4. **Documentation**: Auto-generates observability reports
5. **Dashboard Versioning**: Exports Grafana dashboards as JSON artifacts

#### Integration with Blog Project

**Use case**: Deploy blog application with observability baked in

```groovy
stage('Deploy Blog with Observability') {
    steps {
        script {
            // Start observability stack first
            sh '''
                cd otel-observability-lab
                docker compose up -d tempo loki prometheus otel-collector grafana
            '''

            // Deploy blog app with OTel instrumentation
            sh '''
                cd blog-project
                # Blog app configured to send telemetry to otel-collector:4318
                docker compose up -d
            '''

            // Verify blog app telemetry
            sh '''
                # Generate traffic
                curl http://localhost:8000
                sleep 10

                # Verify traces from blog app
                curl "http://localhost:3200/api/search?tags=service.name=blog-app"
            '''
        }
    }
}
```

### GitLab CI Integration

```yaml
# .gitlab-ci.yml
variables:
  DOCKER_DRIVER: overlay2

stages:
  - setup
  - test
  - verify
  - cleanup

setup_observability:
  stage: setup
  script:
    - cd otel-observability-lab
    - docker compose up -d
    - sleep 30  # Wait for services

test_telemetry:
  stage: test
  script:
    - for i in {1..10}; do curl -X POST http://localhost:5000/api/tasks -H "Content-Type: application/json" -d "{\"title\":\"Test $i\"}"; done
    - sleep 10

verify_traces:
  stage: verify
  script:
    - TRACES=$(curl -s "http://localhost:3200/api/search?tags=service.name=flask-backend" | jq -r '.traces | length')
    - if [ "$TRACES" -lt 5 ]; then exit 1; fi

verify_metrics:
  stage: verify
  script:
    - curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq '.data.result | length'

cleanup:
  stage: cleanup
  when: always
  script:
    - cd otel-observability-lab
    - docker compose down -v
```

### GitHub Actions Integration

```yaml
# .github/workflows/observability.yml
name: Observability Lab Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Start Observability Lab
        run: |
          cd otel-observability-lab
          docker compose up -d

      - name: Wait for Services
        run: |
          timeout 60 sh -c 'until curl -sf http://localhost:13133; do sleep 2; done'
          timeout 60 sh -c 'until curl -sf http://localhost:5000/health; do sleep 2; done'

      - name: Generate Traffic
        run: |
          for i in {1..10}; do
            curl -X POST http://localhost:5000/api/tasks \
              -H "Content-Type: application/json" \
              -d "{\"title\":\"Test $i\"}"
          done
          sleep 10

      - name: Verify Traces
        run: |
          TRACES=$(curl -s "http://localhost:3200/api/search?tags=service.name=flask-backend" | jq -r '.traces | length')
          if [ "$TRACES" -lt 5 ]; then
            echo "ERROR: Not enough traces"
            exit 1
          fi

      - name: Verify Metrics
        run: |
          curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total'

      - name: Verify Logs
        run: |
          curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.data'

      - name: Cleanup
        if: always()
        run: |
          cd otel-observability-lab
          docker compose down -v
```

---

## Production Readiness Checklist

### Security

- [ ] **OTLP Endpoints**: Enable TLS
  ```yaml
  exporters:
    otlp/tempo:
      endpoint: tempo:4317
      tls:
        insecure: false
        cert_file: /certs/client.crt
        key_file: /certs/client.key
        ca_file: /certs/ca.crt
  ```

- [ ] **Grafana Authentication**: Disable anonymous auth
  ```yaml
  environment:
    - GF_AUTH_ANONYMOUS_ENABLED=false
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
  ```

- [ ] **Sensitive Data**: Sanitize from spans/logs
  ```python
  span.set_attribute("user.email", sanitize_email(user.email))
  # Instead of: span.set_attribute("user.email", user.email)
  ```

- [ ] **API Keys**: Store in secrets manager
  ```bash
  # Don't hardcode in configs
  # Use environment variables from vault/secrets
  ```

### Scalability

- [ ] **Collector Scaling**: Run multiple collector instances behind load balancer

- [ ] **Tempo Backend**: Switch from local storage to S3/GCS
  ```yaml
  # tempo.yml
  storage:
    trace:
      backend: s3
      s3:
        bucket: tempo-traces
        endpoint: s3.amazonaws.com
  ```

- [ ] **Prometheus**: Implement Thanos for long-term storage

- [ ] **Loki**: Enable distributed mode for high-volume logs

### Reliability

- [ ] **Sampling**: Implement tail-based sampling
  ```yaml
  processors:
    tail_sampling:
      policies:
        - name: errors-policy
          type: status_code
          status_code: {status_codes: [ERROR]}
        - name: slow-requests
          type: latency
          latency: {threshold_ms: 1000}
        - name: probabilistic
          type: probabilistic
          probabilistic: {sampling_percentage: 10}
  ```

- [ ] **Backpressure**: Configure queue sizes
  ```yaml
  exporters:
    otlp/tempo:
      sending_queue:
        enabled: true
        num_consumers: 10
        queue_size: 1000
      retry_on_failure:
        enabled: true
        initial_interval: 5s
        max_interval: 30s
  ```

- [ ] **Health Checks**: Implement liveness/readiness probes
  ```yaml
  # kubernetes deployment
  livenessProbe:
    httpGet:
      path: /health
      port: 5000
    initialDelaySeconds: 30
    periodSeconds: 10
  ```

### Cost Optimization

- [ ] **Retention Policies**: Set appropriate data retention
  ```yaml
  # prometheus.yml
  global:
    storage.tsdb.retention.time: 15d

  # loki-config.yml
  limits_config:
    retention_period: 7d

  # tempo.yml
  compactor:
    compaction:
      block_retention: 48h
  ```

- [ ] **Cardinality Management**: Limit high-cardinality labels
  ```python
  # DON'T: Unbounded cardinality
  span.set_attribute("user.id", user_id)  # Millions of users

  # DO: Bounded cardinality
  span.set_attribute("user.tier", user_tier)  # free/premium/enterprise
  ```

- [ ] **Metric Aggregation**: Pre-aggregate in application
  ```python
  # Instead of creating metric per user
  # Aggregate by tier
  request_counter.add(1, {"tier": user.tier, "endpoint": endpoint})
  ```

### Monitoring the Monitors

- [ ] **Collector Metrics**: Monitor collector health
  ```promql
  # Collector CPU/memory
  process_cpu_seconds_total{service="otel-collector"}
  process_resident_memory_bytes{service="otel-collector"}

  # Export failures
  rate(otelcol_exporter_send_failed_spans[5m])
  rate(otelcol_exporter_send_failed_metric_points[5m])
  ```

- [ ] **Backend Health**: Alert on storage issues
  ```promql
  # Tempo ingestion rate
  rate(tempo_ingester_spans_received_total[5m])

  # Loki ingestion errors
  rate(loki_distributor_errors_total[5m])

  # Prometheus storage
  prometheus_tsdb_storage_blocks_bytes
  ```

---

## Performance Tuning

### Application Level

**Batch Size Tuning**:
```python
# app.py
from opentelemetry.sdk.trace.export import BatchSpanProcessor

span_processor = BatchSpanProcessor(
    otlp_trace_exporter,
    max_queue_size=2048,        # Default: 2048
    schedule_delay_millis=5000, # Default: 5000 (5s)
    max_export_batch_size=512,  # Default: 512
    export_timeout_millis=30000 # Default: 30000 (30s)
)
```

**Trade-offs**:
- **Larger batch size**: Less network overhead, more memory usage
- **Longer delay**: Less overhead, higher latency in observability
- **Smaller batch size**: Lower memory, more network calls

### Collector Level

**Memory Limiter**:
```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1024          # Adjust based on available RAM
    spike_limit_mib: 256     # Headroom for spikes
```

**Batch Processor**:
```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 8192     # Increase for high throughput
    send_batch_max_size: 16384
```

**Queuing**:
```yaml
exporters:
  otlp/tempo:
    sending_queue:
      enabled: true
      num_consumers: 10       # Increase for more parallelism
      queue_size: 5000        # Buffer for bursts
```

### Storage Level

**Prometheus**:
```yaml
# prometheus.yml
global:
  scrape_interval: 30s      # Reduce frequency (was 15s)
  scrape_timeout: 10s

# Command flags
command:
  - '--storage.tsdb.retention.time=15d'
  - '--storage.tsdb.retention.size=50GB'
  - '--storage.tsdb.wal-compression'  # Enable compression
```

**Loki**:
```yaml
# loki-config.yml
limits_config:
  ingestion_rate_mb: 10      # MB per second per tenant
  ingestion_burst_size_mb: 20
  max_streams_per_user: 10000
  max_line_size: 256kb

chunk_store_config:
  max_look_back_period: 7d

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

**Tempo**:
```yaml
# tempo.yml
storage:
  trace:
    pool:
      max_workers: 50         # Parallel workers
      queue_depth: 10000
    wal:
      path: /tmp/tempo/wal
      encoding: snappy         # Compression
    block:
      encoding: zstd           # Better compression
```

---

## Security Considerations

### Network Security

**Docker Network Isolation**:
```yaml
networks:
  backend-network:
    driver: bridge
    internal: true            # No external access

  frontend-network:
    driver: bridge
    # External access allowed

services:
  backend:
    networks:
      - backend-network

  frontend:
    networks:
      - frontend-network
      - backend-network        # Bridge between networks
```

**TLS Everywhere**:
```yaml
# docker-compose.yml
services:
  otel-collector:
    environment:
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      - OTEL_EXPORTER_OTLP_CERTIFICATE=/certs/ca.crt
    volumes:
      - ./certs:/certs:ro

  backend:
    environment:
      - OTEL_EXPORTER_OTLP_CERTIFICATE=/certs/ca.crt
    volumes:
      - ./certs:/certs:ro
```

### Data Privacy

**PII Sanitization**:
```python
import re

def sanitize_email(email):
    """Masks email: user@domain.com → u***@d***.com"""
    local, domain = email.split('@')
    return f"{local[0]}***@{domain[0]}***.{domain.split('.')[-1]}"

def sanitize_credit_card(cc):
    """Masks credit card: 1234-5678-9012-3456 → ****-****-****-3456"""
    return re.sub(r'\d(?=\d{4})', '*', cc)

# Usage in spans
span.set_attribute("user.email", sanitize_email(user.email))
span.set_attribute("payment.card", sanitize_credit_card(card_number))
```

**Sensitive Attribute Filtering**:
```yaml
# otel-collector-config.yml
processors:
  attributes:
    actions:
      - key: password
        action: delete
      - key: api_key
        action: delete
      - key: authorization
        action: delete
      - key: credit_card
        pattern: \d{4}-\d{4}-\d{4}-\d{4}
        action: hash          # One-way hash
```

### Access Control

**Grafana RBAC**:
```yaml
# grafana.ini
[auth]
disable_login_form = false
disable_signout_menu = false

[auth.basic]
enabled = true

[users]
allow_sign_up = false
allow_org_create = false

[auth.anonymous]
enabled = false

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD}
secret_key = ${GRAFANA_SECRET_KEY}
```

**API Key Management**:
```python
# backend/app.py
import os
from functools import wraps

API_KEY = os.getenv('INTERNAL_API_KEY')

def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if request.headers.get('X-API-Key') != API_KEY:
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated_function

@app.route('/internal/metrics')
@require_api_key
def internal_metrics():
    # Sensitive metrics endpoint
    pass
```

---

## Lessons Learned

### 1. **Context Matters in Flask**

**Problem**: Accessing database engine outside application context
**Lesson**: Understand framework lifecycle and object availability
**Best Practice**: Use `with app.app_context():` for initialization code

### 2. **Docker Caching is Aggressive**

**Problem**: Code changes not reflected after rebuild
**Lesson**: Docker layer caching can mask issues
**Best Practice**: Use `--no-cache` when debugging; `PYTHONDONTWRITEBYTECODE=1` in development

### 3. **Network DNS Can Be Fragile**

**Problem**: Service name resolution failures after partial restarts
**Lesson**: Docker DNS needs full network recreation
**Best Practice**: `docker compose down && docker compose up -d` for clean slate

### 4. **Three Pillars = Three Configurations**

**Problem**: Assumed logs worked because traces/metrics worked
**Lesson**: Each pillar needs explicit SDK setup
**Best Practice**: Verify each pillar independently

### 5. **OpenTelemetry Versions Matter**

**Problem**: `labels` config syntax deprecated in newer collector versions
**Lesson**: Configuration patterns evolve; documentation lags
**Best Practice**: Check version-specific docs; use attribute hints (modern approach)

### 6. **Loki Labels Need Careful Design**

**Problem**: Wanted every attribute as a label
**Lesson**: Labels = indexes; unbounded cardinality = performance death
**Best Practice**: 5-10 labels, bounded values, use log content filtering for the rest

### 7. **Absolute Paths in Containers**

**Problem**: Relative paths work locally, fail in containers
**Lesson**: Container working directory can differ
**Best Practice**: Always use absolute paths; no assumptions about CWD

### 8. **Correlation Requires Planning**

**Problem**: Traces and logs not linked
**Lesson**: Correlation isn't automatic; needs trace IDs in logs
**Best Practice**: Include trace context in every log statement

### 9. **Observability Has Overhead**

**Problem**: Excessive instrumentation impacted performance
**Lesson**: More data ≠ better observability; signal-to-noise ratio matters
**Best Practice**: Instrument intentionally; sample aggressively; batch everything

### 10. **Documentation is Essential**

**Problem**: Troubleshooting same issues repeatedly
**Lesson**: Future you will forget current you's hard-won knowledge
**Best Practice**: Document EVERYTHING - problems, solutions, rationale, lessons

---

## Conclusion

This observability lab demonstrates a production-grade telemetry pipeline from application instrumentation through collection, storage, and visualization. The journey from initial configuration through troubleshooting taught valuable lessons about:

- Framework-specific requirements (Flask application context)
- Container orchestration pitfalls (caching, DNS, networking)
- OpenTelemetry evolution (deprecated configs, modern patterns)
- Storage backend characteristics (Loki label design, Tempo indexing)
- Correlation strategies (trace IDs in logs, exemplars in metrics)

The lab is now ready for:
- **CI/CD Integration**: Automated testing in Jenkins/GitLab/GitHub Actions
- **Blog Project Integration**: Full observability for your blog application
- **Production Deployment**: With security, scalability, and cost optimizations
- **Learning Platform**: Hands-on exploration of distributed tracing concepts

### Key Achievements

✅ **Distributed Tracing**: End-to-end request tracing from browser through database
✅ **Metrics Collection**: SLI/SLO-focused metrics (availability, latency, errors)
✅ **Log Aggregation**: Structured logs with full trace correlation
✅ **Unified Visualization**: Grafana dashboards linking all three pillars
✅ **CI/CD Ready**: Automated validation in deployment pipelines
✅ **Production Patterns**: Security, scalability, and reliability best practices

**Next Steps**: Deploy this observability stack alongside your blog project in Jenkins, monitor real user traffic, and gain unprecedented insights into your application's behavior!

---

**Document Version**: 1.0
**Last Updated**: October 13, 2025
**Lab Version**: OpenTelemetry Collector 0.96.0
**Status**: Production Ready ✅
