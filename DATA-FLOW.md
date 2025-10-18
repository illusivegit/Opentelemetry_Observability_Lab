# Data Flow Visualization - End-to-End Observability

This document visualizes how observability data flows through your system from user input to database and back.

---

## Complete Request Flow with Observability

### 1. User Creates a Task

```
┌─────────────────────────────────────────────────────────────────────┐
│ BROWSER (http://localhost:8080)                                     │
│                                                                      │
│ User Action: Clicks "Add Task" button                               │
│   ↓                                                                  │
│ JavaScript Event: handleFormSubmit()                                │
│   ↓                                                                  │
│ OTEL Browser SDK (otel-browser.js)                                  │
│   • FetchInstrumentation intercepts request                         │
│   • Creates root span: "HTTP POST /api/tasks"                       │
│   • Generates trace_id: a1b2c3d4e5f6789...                         │
│   • Generates span_id: 9876543210abcdef                             │
│   • Adds W3C traceparent header                                     │
│                                                                      │
│ Fetch Request:                                                       │
│   POST http://localhost:5000/api/tasks                              │
│   Headers:                                                           │
│     traceparent: 00-a1b2c3d4e5f6789...-9876543210abcdef-01         │
│     Content-Type: application/json                                  │
│   Body:                                                              │
│     {                                                                │
│       "title": "Learn OpenTelemetry",                               │
│       "description": "Complete the observability lab",              │
│       "completed": false                                            │
│     }                                                                │
│                                                                      │
│ OTEL Export:                                                         │
│   → Sends trace to: http://localhost:4318/v1/traces                │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ FLASK BACKEND (http://localhost:5000)                               │
│                                                                      │
│ Request Received at app.py:125                                      │
│   ↓                                                                  │
│ @app.before_request (line 125)                                      │
│   • Captures request.start_time = time.time()                       │
│   • Extracts trace context from traceparent header                  │
│   • Logs: "Incoming request" with trace_id                          │
│                                                                      │
│ FlaskInstrumentor (auto)                                            │
│   • Creates child span: "POST /api/tasks"                           │
│   • Links to parent span from browser                               │
│   • Sets attributes:                                                 │
│       http.method: POST                                             │
│       http.route: /api/tasks                                        │
│       http.url: http://localhost:5000/api/tasks                    │
│   ↓                                                                  │
│ Route Handler: create_task() (line 232)                            │
│   • Creates custom span: "create_task"                              │
│   • Validates input data                                            │
│   • Sets span attribute: task.title="Learn OpenTelemetry"          │
│   • Creates Task model instance                                     │
│   ↓                                                                  │
│ Database Operation (line 249)                                        │
│   • db.session.add(new_task)                                        │
│   • db.session.commit()                                             │
│   ↓                                                                  │
│ SQLAlchemyInstrumentor (auto)                                       │
│   • Creates database span: "INSERT INTO tasks"                      │
│   • Measures query_start = time.time()                              │
│   • Executes SQL: INSERT INTO tasks (title, description, ...)      │
│   • Calculates query_duration = time.time() - query_start          │
│   • Sets span attributes:                                            │
│       db.system: sqlite                                             │
│       db.statement: INSERT INTO tasks...                            │
│       db.query.duration: 0.0023 (seconds)                           │
│   ↓                                                                  │
│ Metrics Recording (line 254-257)                                    │
│   • database_query_duration.record(0.0023, {                        │
│       "operation": "insert",                                        │
│       "table": "tasks"                                              │
│     })                                                               │
│   ↓                                                                  │
│ Structured Logging (line 261)                                       │
│   • logger.info(f"Created new task {new_task.id}: {title}")        │
│   • JSON output:                                                     │
│     {                                                                │
│       "timestamp": "2025-10-11T14:23:45.123Z",                      │
│       "level": "INFO",                                              │
│       "message": "Created new task 1: Learn OpenTelemetry",         │
│       "trace_id": "a1b2c3d4e5f6789...",                            │
│       "span_id": "fedcba0987654321",                                │
│       "service.name": "flask-backend"                               │
│     }                                                                │
│   ↓                                                                  │
│ Response Return (line 263)                                          │
│   • jsonify(new_task.to_dict()), 201                               │
│   ↓                                                                  │
│ @app.after_request (line 138)                                       │
│   • duration = time.time() - request.start_time                     │
│   • Records metrics:                                                 │
│       request_counter.add(1, {                                      │
│         "method": "POST",                                           │
│         "endpoint": "create_task",                                  │
│         "status_code": "201"                                        │
│       })                                                             │
│       request_duration.record(0.0245, {                             │
│         "method": "POST",                                           │
│         "endpoint": "create_task",                                  │
│         "status_code": "201"                                        │
│       })                                                             │
│   • Logs: "Request completed" with duration                         │
│                                                                      │
│ OTEL Export (automatic):                                            │
│   → Traces to: http://otel-collector:4318/v1/traces                │
│   → Metrics to: http://otel-collector:4318/v1/metrics              │
│   → Logs to: http://otel-collector:4318/v1/logs                    │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│ OPENTELEMETRY COLLECTOR (otel-collector:4318)                       │
│                                                                      │
│ Receivers:                                                           │
│   • OTLP HTTP receiver (port 4318)                                  │
│   • Accepts: traces, metrics, logs                                  │
│   • CORS enabled for browser requests                               │
│   ↓                                                                  │
│ Processors:                                                          │
│   1. memory_limiter: Prevents OOM (512MB limit)                     │
│   2. resource: Adds service.instance.id                             │
│   3. attributes: Adds environment="lab"                             │
│   4. batch: Aggregates data (10s timeout)                           │
│   ↓                                                                  │
│ Exporters:                                                           │
│   ┌──────────────────────────────────────────────────────┐         │
│   │ TRACES → Tempo (otlp/tempo)                          │         │
│   │   • endpoint: tempo:4317                              │         │
│   │   • protocol: gRPC                                    │         │
│   │   • Exports complete trace tree                       │         │
│   └──────────────────────────────────────────────────────┘         │
│   ┌──────────────────────────────────────────────────────┐         │
│   │ METRICS → Prometheus (prometheusremotewrite)         │         │
│   │   • endpoint: http://prometheus:9090/api/v1/write    │         │
│   │   • Also exposed on :8889 for scraping               │         │
│   │   • Metrics include:                                  │         │
│   │     - http_requests_total                             │         │
│   │     - http_request_duration_seconds                   │         │
│   │     - database_query_duration_seconds                 │         │
│   │     - http_errors_total                               │         │
│   └──────────────────────────────────────────────────────┘         │
│   ┌──────────────────────────────────────────────────────┐         │
│   │ LOGS → Loki                                           │         │
│   │   • endpoint: http://loki:3100/loki/api/v1/push      │         │
│   │   • Labels extracted: service_name, level             │         │
│   │   • Preserves trace_id for correlation                │         │
│   └──────────────────────────────────────────────────────┘         │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
               ┌───────────────┼───────────────┐
               │               │               │
               ▼               ▼               ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │    TEMPO     │  │  PROMETHEUS  │  │     LOKI     │
    │   (Traces)   │  │   (Metrics)  │  │    (Logs)    │
    │  Port: 3200  │  │  Port: 9090  │  │  Port: 3100  │
    └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
           │                 │                  │
           │  Storage:       │  Storage:        │  Storage:
           │  /tmp/tempo     │  /prometheus     │  /loki
           │                 │                  │
           │  Retention:     │  Retention:      │  Retention:
           │  1 hour         │  15 days         │  7 days
           │                 │                  │
           └─────────────────┴──────────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │     GRAFANA     │
                   │   Port: 3000    │
                   │                 │
                   │  Datasources:   │
                   │  • Tempo        │
                   │  • Prometheus   │
                   │  • Loki         │
                   │                 │
                   │  Dashboards:    │
                   │  • SLI/SLO      │
                   │  • Tracing      │
                   └─────────────────┘
```

---

## Trace Hierarchy Breakdown

### Complete Trace Tree for "Create Task" Request

```
Trace ID: a1b2c3d4e5f6789...
Total Duration: 24.5ms

├─ [Span 1] HTTP POST (Browser) - 24.5ms
│  └─ Service: frontend-browser
│  └─ Attributes:
│     • http.method: POST
│     • http.url: http://localhost:5000/api/tasks
│     • component: fetch
│  └─ Events: None
│  └─ Status: OK
│
   └─ [Span 2] POST /api/tasks (Flask) - 23.1ms
      └─ Service: flask-backend
      └─ Parent: Span 1
      └─ Attributes:
         • http.method: POST
         • http.route: /api/tasks
         • http.status_code: 201
         • http.target: /api/tasks
      └─ Events: None
      └─ Status: OK
      │
      └─ [Span 3] create_task (Business Logic) - 21.8ms
         └─ Service: flask-backend
         └─ Parent: Span 2
         └─ Attributes:
            • task.title: "Learn OpenTelemetry"
            • task.id: 1
            • db.query.duration: 0.0023
         └─ Events: None
         └─ Status: OK
         │
         └─ [Span 4] INSERT INTO tasks (Database) - 2.3ms
            └─ Service: flask-backend
            └─ Parent: Span 3
            └─ Attributes:
               • db.system: sqlite
               • db.statement: INSERT INTO tasks (title, description, completed, created_at) VALUES (?, ?, ?, ?)
               • db.name: tasks.db
               • db.operation: insert
            └─ Events: None
            └─ Status: OK
```

---

## Metrics Data Flow

### Request Metrics Timeline

```
Time: T+0ms    - Request arrives at Flask
Time: T+0.5ms  - before_request() middleware executes
                 • Captures start_time
                 • Logs "Incoming request"

Time: T+2ms    - Route handler create_task() starts
                 • Validates input
                 • Creates Task object

Time: T+20ms   - Database query executes
                 • SQLAlchemy INSERT
                 • Duration: 2.3ms

Time: T+22ms   - Metrics recorded:
                 • database_query_duration.record(0.0023)

Time: T+24ms   - Response ready, after_request() executes:
                 • request_counter.add(1)
                 • request_duration.record(0.024)
                 • Logs "Request completed"

Time: T+24.5ms - Response sent to client
```

### Metrics Exported to Prometheus

```
# http_requests_total
http_requests_total{method="POST",endpoint="create_task",status_code="201"} 1

# http_request_duration_seconds (histogram)
http_request_duration_seconds_bucket{method="POST",endpoint="create_task",status_code="201",le="0.005"} 0
http_request_duration_seconds_bucket{method="POST",endpoint="create_task",status_code="201",le="0.01"} 0
http_request_duration_seconds_bucket{method="POST",endpoint="create_task",status_code="201",le="0.025"} 1
http_request_duration_seconds_bucket{method="POST",endpoint="create_task",status_code="201",le="0.05"} 1
http_request_duration_seconds_sum{method="POST",endpoint="create_task",status_code="201"} 0.024
http_request_duration_seconds_count{method="POST",endpoint="create_task",status_code="201"} 1

# database_query_duration_seconds (histogram)
database_query_duration_seconds_bucket{operation="insert",table="tasks",le="0.001"} 0
database_query_duration_seconds_bucket{operation="insert",table="tasks",le="0.0025"} 1
database_query_duration_seconds_bucket{operation="insert",table="tasks",le="0.005"} 1
database_query_duration_seconds_sum{operation="insert",table="tasks"} 0.0023
database_query_duration_seconds_count{operation="insert",table="tasks"} 1
```

---

## Log Data Flow

### Structured Logs Generated

```json
// Log 1: Request arrives
{
  "timestamp": "2025-10-11T14:23:45.100Z",
  "name": "app",
  "level": "INFO",
  "message": "Incoming request",
  "method": "POST",
  "path": "/api/tasks",
  "trace_id": "a1b2c3d4e5f6789abcdef0123456789",
  "span_id": "fedcba0987654321",
  "service.name": "flask-backend"
}

// Log 2: Task created
{
  "timestamp": "2025-10-11T14:23:45.122Z",
  "name": "app",
  "level": "INFO",
  "message": "Created new task 1: Learn OpenTelemetry",
  "trace_id": "a1b2c3d4e5f6789abcdef0123456789",
  "span_id": "fedcba0987654321",
  "service.name": "flask-backend"
}

// Log 3: Request completed
{
  "timestamp": "2025-10-11T14:23:45.124Z",
  "name": "app",
  "level": "INFO",
  "message": "Request completed",
  "method": "POST",
  "path": "/api/tasks",
  "status_code": 201,
  "duration_seconds": 0.024,
  "trace_id": "a1b2c3d4e5f6789abcdef0123456789",
  "span_id": "fedcba0987654321",
  "service.name": "flask-backend"
}
```

### Logs Stored in Loki

```
Loki Stream:
  Labels: {service_name="flask-backend", level="INFO"}
  Entries:
    - timestamp: 2025-10-11T14:23:45.100Z
      line: {"message": "Incoming request", "trace_id": "a1b2c3d4...", ...}
    - timestamp: 2025-10-11T14:23:45.122Z
      line: {"message": "Created new task 1...", "trace_id": "a1b2c3d4...", ...}
    - timestamp: 2025-10-11T14:23:45.124Z
      line: {"message": "Request completed", "trace_id": "a1b2c3d4...", ...}
```

---

## SLI/SLO Calculation Flow

### Real-Time SLI Calculation

```
Every 15 seconds, Prometheus evaluates:

┌─────────────────────────────────────────────────────────┐
│ AVAILABILITY SLI                                        │
├─────────────────────────────────────────────────────────┤
│ Query:                                                   │
│   100 * (1 - (sum(rate(http_errors_total[5m]))         │
│                / sum(rate(http_requests_total[5m]))))   │
│                                                          │
│ Calculation over last 5 minutes:                        │
│   Total requests: 1000                                  │
│   Error requests: 2                                     │
│   Success rate: (1000 - 2) / 1000 = 0.998              │
│   SLI Value: 99.8%                                      │
│                                                          │
│ SLO Target: 99.9%                                       │
│ Status: ⚠️ BREACH (99.8% < 99.9%)                      │
│ Error Budget Consumed: 20% of monthly budget            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ LATENCY SLI (P95)                                       │
├─────────────────────────────────────────────────────────┤
│ Query:                                                   │
│   histogram_quantile(0.95,                              │
│     sum(rate(http_request_duration_seconds_bucket[5m])) │
│     by (le))                                            │
│                                                          │
│ Calculation:                                             │
│   95th percentile latency: 0.245 seconds (245ms)        │
│                                                          │
│ SLO Target: < 500ms                                     │
│ Status: ✅ OK (245ms < 500ms)                           │
│ Margin: 255ms (51% of target)                           │
└─────────────────────────────────────────────────────────┘
```

---

## Correlation Workflow

### How to Follow a Request Across All Three Pillars

```
Step 1: User reports "slow task creation"
   ↓
Step 2: Find the trace
   • Grafana → Explore → Tempo
   • Search: {span.http.route="/api/tasks" && duration > 500ms}
   • Result: Trace ID a1b2c3d4...
   ↓
Step 3: Examine trace hierarchy
   • Total duration: 1.2 seconds
   • Browser span: 1.2s
   •   └─ Flask span: 1.15s
   •       └─ create_task span: 1.1s
   •           └─ Database span: 1.05s ⚠️ SLOW!
   ↓
Step 4: Jump to correlated logs
   • Click "Logs for this span"
   • Query: {service_name="flask-backend"} | json | trace_id="a1b2c3d4..."
   • Find: Log entries showing database lock contention
   ↓
Step 5: Check metrics for pattern
   • Switch to Prometheus
   • Query: database_query_duration_seconds{operation="insert"}
   • Graph shows spike at that time
   ↓
Step 6: Root cause identified
   • Database was locked due to concurrent writes
   • Solution: Implement write queue or increase connection pool
```

---

## Key Insights

### What Each Layer Tells You

**Traces:**
- WHERE time is spent in your system
- WHICH services/functions are involved
- HOW requests flow through your architecture
- WHAT the call hierarchy looks like

**Metrics:**
- HOW MANY requests are happening
- HOW FAST they're being processed
- WHAT PERCENTAGE are failing
- WHEN performance degrades

**Logs:**
- WHY something happened
- WHAT the exact error was
- WHO triggered the action
- WHEN specific events occurred

### The Power of Correlation

```
Without Correlation:
  Trace: "This request was slow" (but why?)
  Logs: "Database error occurred" (but for which request?)
  Metrics: "Error rate increased" (but where?)

With Correlation:
  Trace (ID: a1b2c3d4) → Slow request identified
    ↓ (trace_id link)
  Logs (trace_id: a1b2c3d4) → "SQLITE_BUSY: database is locked"
    ↓ (time correlation)
  Metrics (at same timestamp) → database_query_duration spike

  Result: Complete picture of the incident
```

---

## Summary

This observability lab demonstrates:

1. **Automatic Instrumentation**: OTEL SDKs capture most data automatically
2. **Context Propagation**: Trace IDs flow through all layers
3. **Multi-Signal Correlation**: Traces, metrics, and logs work together
4. **SLI/SLO Tracking**: Real-time compliance monitoring
5. **End-to-End Visibility**: From browser click to database commit

Every request generates:
- 4+ spans (browser, HTTP, business logic, database)
- 3+ metrics (request count, duration, database query time)
- 3+ log entries (request start, business event, request complete)

All correlated by trace_id for complete observability.
