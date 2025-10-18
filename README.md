# OpenTelemetry Observability Lab
## Full-Stack Monitoring with Traces, Metrics, and Logs

A comprehensive, battle-tested hands-on lab demonstrating end-to-end observability using OpenTelemetry for a full-stack application. This lab is designed for DevSecOps and SRE engineers to understand distributed tracing, metrics collection, log aggregation, and SLI/SLO implementation.

**Battle-Tested**: This lab was built through real troubleshooting scenarios, with all issues documented for your learning.

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Technology Stack](#technology-stack)
- [What You'll Learn](#what-youll-learn)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Teardown & Cleanup](#teardown--cleanup)
- [Understanding the Data Flow](#understanding-the-data-flow)
- [Exploring Observability](#exploring-observability)
- [SLI/SLO Implementation](#slislo-implementation)
- [Lab Exercises](#lab-exercises)
- [Troubleshooting](#troubleshooting)
- [Additional Documentation](#additional-documentation)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                            USER BROWSER                             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Frontend (HTML/CSS/JS + OpenTelemetry Browser SDK)          │  │
│  │  - Automatic fetch/XHR instrumentation                       │  │
│  │  - Manual span creation for user interactions                │  │
│  │  - Performance metrics                                        │  │
│  └────────────────────────┬─────────────────────────────────────┘  │
└────────────────────────────┼────────────────────────────────────────┘
                             │
                             │ HTTP Requests
                             │ W3C Trace Context Headers
                             ▼
        ┌────────────────────────────────────────────────┐
        │    Flask Backend (Python)                      │
        │    ┌──────────────────────────────────────┐   │
        │    │  OpenTelemetry Auto-Instrumentation  │   │
        │    │  - Flask requests/responses          │   │
        │    │  - SQLAlchemy queries                │   │
        │    │  - Custom business logic spans       │   │
        │    │  - Structured JSON logs              │   │
        │    │  - Custom metrics (counters/histogr) │   │
        │    └──────────────────┬───────────────────┘   │
        │                       │                        │
        │                       ▼                        │
        │    ┌──────────────────────────────────────┐   │
        │    │  SQLite Database                     │   │
        │    │  - Task storage                      │   │
        │    │  - Fully instrumented queries        │   │
        │    └──────────────────────────────────────┘   │
        └────────────────────┬───────────────────────────┘
                             │
                             │ OTLP/HTTP
                             │ (Traces, Metrics, Logs)
                             ▼
        ┌─────────────────────────────────────────────────┐
        │   OpenTelemetry Collector                       │
        │   ┌─────────────────────────────────────────┐   │
        │   │ Receivers: OTLP (gRPC + HTTP)           │   │
        │   │ Processors: Batch, Resource, Attributes │   │
        │   │ Exporters: Tempo, Prometheus, Loki      │   │
        │   └─────────────────────────────────────────┘   │
        └──┬──────────────────┬──────────────────┬────────┘
           │                  │                  │
           │ Traces           │ Metrics          │ Logs
           ▼                  ▼                  ▼
   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │    Tempo     │  │  Prometheus  │  │     Loki     │
   │   (Traces)   │  │  (Metrics)   │  │    (Logs)    │
   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
          │                 │                  │
          └─────────────────┼──────────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │     Grafana     │
                   │  - Dashboards   │
                   │  - Trace UI     │
                   │  - Log Explorer │
                   │  - SLI/SLO      │
                   └─────────────────┘
```

---

## Technology Stack

### Application Layer
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Backend**: Flask 3.0 (Python)
- **ORM**: Flask-SQLAlchemy
- **Database**: SQLite

### Observability Stack
- **Instrumentation**: OpenTelemetry (Python SDK 1.22.0 + Browser SDK 1.19.0)
- **Collector**: OpenTelemetry Collector Contrib **v0.96.0**
- **Traces**: Grafana Tempo 2.3.1
- **Metrics**: Prometheus 2.48.1
- **Logs**: Grafana Loki 2.9.3
- **Visualization**: Grafana 10.2.3

### Infrastructure
- **Containerization**: Docker & Docker Compose
- **Networking**: Bridge network for service communication

---

## What You'll Learn

### 1. Distributed Tracing
- End-to-end request tracing from browser to database
- W3C Trace Context propagation across services
- Parent-child span relationships
- Span attributes and events
- Exception tracking and error propagation

### 2. Metrics & SLIs
- Request rate (throughput)
- Error rate (reliability)
- Response time percentiles (latency - p50, p95, p99)
- Database query performance
- Custom business metrics

### 3. Log Aggregation
- Structured JSON logging
- Trace-log correlation
- Log levels and filtering
- Contextual logging with trace IDs

### 4. SLI/SLO Implementation
- **Availability SLI**: % of successful requests (target: >99%)
- **Latency SLI**: p95 response time (target: <500ms)
- **Error Budget**: Tracking and visualization
- Real-time SLO dashboards

### 5. Correlation & Context
- Linking traces to logs
- Linking traces to metrics
- Following requests across all three layers
- Service dependency mapping

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ available RAM
- Ports available: 3000, 3100, 3200, 4317, 4318, 5000, 8080, 8888, 9090

---

## Quick Start

### Option 1: Automated Start (Recommended)

The easiest way to start the lab:

```bash
# Navigate to lab directory
cd otel-observability-lab

# Run the startup script
./start-lab.sh
```

The script will:
- ✅ Check Docker is running
- ✅ Check docker compose is available
- ✅ Clean up any existing containers
- ✅ Start all services
- ✅ Wait for services to initialize
- ✅ Perform health checks
- ✅ Display access URLs and helpful tips

**Services Started:**
- Flask Backend (port 5000)
- Frontend (port 8080)
- OpenTelemetry Collector (ports 4317, 4318, 13133)
- Grafana Tempo (port 3200)
- Prometheus (port 9090)
- Grafana Loki (port 3100)
- Grafana (port 3000)

### Option 2: Manual Start

If you prefer manual control:

```bash
# Navigate to lab directory
cd otel-observability-lab

# Start all services
docker compose up -d

# Wait ~30 seconds for initialization

# Check service health
docker compose ps

# View logs (optional)
docker compose logs -f
```

### Access the Application

Once started (either method), access:
- **Frontend**: http://localhost:8080
- **Grafana**: http://localhost:3000 (anonymous login enabled)
- **Prometheus**: http://localhost:9090
- **Tempo**: http://localhost:3200/ready
- **Loki**: http://localhost:3100/ready
- **Collector Health**: http://localhost:13133

---

## Teardown & Cleanup

### Quick Teardown

Stop and remove all containers:

```bash
docker compose down
```

This removes:
- All containers
- The default network
- **Keeps**: Named volumes (data persists)

### Complete Cleanup

To remove **everything** including stored data:

```bash
# Remove containers, networks, AND volumes
docker compose down -v
```

This removes:
- All containers
- The default network
- All named volumes:
  - `backend-data` (SQLite database)
  - `tempo-data` (trace storage)
  - `loki-data` (log storage)
  - `prometheus-data` (metrics storage)
  - `grafana-data` (dashboard configs)

⚠️ **Warning**: Using `-v` flag will delete all telemetry data. Use this for a fresh start.

### Partial Cleanup

Rebuild specific service:

```bash
# Rebuild backend (useful after code changes)
docker compose build --no-cache backend
docker compose up -d backend

# Restart specific service
docker compose restart otel-collector

# View logs for debugging
docker compose logs -f backend
```

### Clean Restart

For a completely fresh environment:

```bash
# Full cleanup
docker compose down -v

# Remove any orphaned containers
docker system prune -f

# Start fresh
./start-lab.sh
```

---

## Understanding the Data Flow

### Request Journey: Frontend → Backend → Database → Response

#### Step 1: User Interaction (Browser)
```javascript
// User clicks "Add Task"
// OpenTelemetry Browser SDK automatically:
1. Creates a root span for the fetch request
2. Adds W3C traceparent header
3. Sends trace to OTEL Collector
4. Records performance timing
```

#### Step 2: Backend Processing (Flask)
```python
# app.py:146-170
# Flask receives request with trace context
1. FlaskInstrumentor extracts trace context from headers
2. Creates child span linked to browser span
3. Executes business logic (create_task)
4. SQLAlchemyInstrumentor wraps database query
5. Creates database span with query details
6. Logs structured JSON with trace_id and span_id
7. Records custom metrics (request count, duration)
8. Returns response
```

#### Step 3: Database Layer (SQLite)
```python
# Automatic instrumentation captures:
1. SQL query text
2. Query duration
3. Database name
4. Operation type (INSERT, SELECT, UPDATE, DELETE)
```

#### Step 4: Observability Pipeline
```yaml
# otel-collector-config.yml
1. Collector receives telemetry via OTLP
2. Batch processor aggregates data
3. Resource processor adds metadata
4. Exporters send to backends:
   - Traces → Tempo
   - Metrics → Prometheus
   - Logs → Loki
```

---

## Exploring Observability

### Exercise 1: Create Your First Task

1. Open http://localhost:8080
2. Create a new task:
   - Title: "Test Observability"
   - Description: "Learning OpenTelemetry"
3. Click "Add Task"

**Now let's trace this request:**

### Finding the Trace in Grafana

1. Open Grafana: http://localhost:3000
2. Navigate to **Explore** (compass icon)
3. Select **Tempo** datasource
4. Click **Search** tab
5. Look for recent traces with:
   - Service Name: `flask-backend`
   - Span Name: `create_task`

**What you'll see:**
```
Browser Span (frontend-browser)
  └─> HTTP POST /api/tasks (flask-backend)
       └─> create_task (business logic)
            └─> INSERT INTO tasks (SQLAlchemy)
```

### Understanding Span Details

Click on any span to see:
- **Duration**: How long the operation took
- **Attributes**:
  - `http.method`: POST
  - `http.route`: /api/tasks
  - `http.status_code`: 201
  - `task.title`: "Test Observability"
  - `db.query.duration`: Query execution time
- **Events**: Exception details if errors occurred
- **Logs**: Link to correlated log entries

---

### Exercise 2: View Correlated Logs

1. In the trace view, find the backend span
2. Click on "Logs for this span" link
3. You'll see structured JSON logs:

```json
{
  "timestamp": "2025-10-13T11:34:32.029Z",
  "level": "INFO",
  "message": "Created new task 6: Test task for label verification",
  "trace_id": "542b72fbc89a2f3193ad6a35e5bf6b39",
  "span_id": "e350cf8075afe40a",
  "service.name": "flask-backend"
}
```

**Alternative: Query Logs Directly in Loki**

Navigate to **Explore** → **Loki** datasource and try:

```logql
# All logs from flask-backend
{service_name="flask-backend"}

# Filter by log level
{service_name="flask-backend", level="ERROR"}

# Search within logs
{service_name="flask-backend"} |= "Created new task"

# Filter by trace ID
{service_name="flask-backend"} | json | trace_id="542b72fbc89a2f3193ad6a35e5bf6b39"
```

**Key Points:**
- Trace ID links logs to distributed trace
- All logs from this request are correlated
- JSON structure allows easy filtering
- **service_name label** enables powerful filtering (added via attribute hints)

---

### Exercise 3: Analyze Metrics & SLIs

1. Navigate to **Dashboards** → **SLI/SLO Dashboard - Task Manager**

**Key Metrics to Observe:**

#### Service Availability (SLI)
```promql
100 * (1 - (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))))
```
- **Target**: >99%
- **Current**: Should show 100% for successful requests

#### P95 Response Time (SLI)
```promql
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```
- **Target**: <500ms
- **What it means**: 95% of requests complete within this time

#### Request Rate by Endpoint
- Shows traffic distribution
- Identify hot paths
- Capacity planning insights

#### Error Rate by Endpoint
- Percentage of failed requests per endpoint
- Helps identify problematic areas

---

### Exercise 4: Simulate Performance Issues

The lab includes testing endpoints to observe system behavior under stress.

#### Test 1: Slow Request
```bash
# In the browser, click "Simulate Slow Request"
# Or use curl:
curl http://localhost:5000/api/simulate-slow?delay=2
```

**Observe in Grafana:**
1. Go to **Explore** → **Tempo**
2. Find the slow trace
3. Notice the 2-second span duration
4. Check the P95 latency metric spike

#### Test 2: Error Simulation
```bash
# Click "Simulate Error" in the UI
# Or use curl:
curl http://localhost:5000/api/simulate-error
```

**Observe:**
1. Trace shows error status (StatusCode.ERROR)
2. Exception details in span events
3. Error counter metric increases
4. Service availability SLI decreases

#### Test 3: Bulk Operations
```bash
# Click "Create Bulk Tasks (5)"
```

**Observe:**
1. Multiple parallel traces
2. Database query patterns
3. Request rate spike
4. Performance under concurrent load

---

## SLI/SLO Implementation

### Defined SLIs

#### 1. Availability SLI
**Definition**: Percentage of successful HTTP requests
```python
# Tracked in app.py:142-150
request_counter.add(1, {
    "method": request.method,
    "endpoint": request.endpoint,
    "status_code": str(response.status_code)
})
```

**Formula**:
```
Availability = (Total Requests - Error Requests) / Total Requests * 100
```

**SLO Target**: 99.9% (3 nines)
- **Error Budget**: 0.1% = ~43 minutes downtime/month

#### 2. Latency SLI
**Definition**: P95 response time for all requests
```python
# Tracked in app.py:146-150
request_duration.record(duration, {
    "method": request.method,
    "endpoint": request.endpoint,
    "status_code": str(response.status_code)
})
```

**SLO Target**: 95% of requests < 500ms

**Error Budget**: 5% of requests can exceed 500ms

#### 3. Database Performance SLI
**Definition**: P95 database query latency
```python
# Tracked in app.py:178, 203, 233, 264, 294
database_query_duration.record(query_duration_time, {
    "operation": "select|insert|update|delete",
    "table": "tasks"
})
```

**SLO Target**: 95% of queries < 100ms

---

### Monitoring SLO Compliance

#### Real-Time Dashboard
The **SLI/SLO Dashboard** provides:
- Current SLI values vs targets
- Historical trends
- Error budget burn rate
- Alert thresholds (visual indicators)

#### Alert Rules (Production-Ready)
```yaml
# Example Prometheus alert rules
groups:
  - name: slo_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))) > 0.01
        for: 5m
        annotations:
          summary: "Error rate above 1% (SLO breach)"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 0.5
        for: 5m
        annotations:
          summary: "P95 latency above 500ms (SLO breach)"
```

---

## Lab Exercises

### Exercise 1: Trace a Complete CRUD Workflow

**Objective**: Follow a single task through its entire lifecycle

1. **Create** a task
2. **Read** the task (refresh the page)
3. **Update** the task (mark as complete)
4. **Delete** the task

**Tasks**:
- Find all 4 operations in Grafana Tempo
- Compare span durations
- Identify which operation is slowest
- Examine database query differences

**Questions to Answer**:
- How many spans are created for each operation?
- What's the relationship between HTTP spans and DB spans?
- How does trace context propagate?

---

### Exercise 2: Identify Performance Bottlenecks

**Objective**: Use traces to find slow operations

1. Create 10 tasks quickly
2. Navigate to Grafana → Explore → Tempo
3. Use TraceQL query:
```traceql
{duration > 100ms}
```

**Analysis**:
- Which spans contribute most to latency?
- Is the slowness in network, application, or database?
- How would you optimize the slowest span?

---

### Exercise 3: Debug an Error

**Objective**: Use observability to root-cause an error

1. Click "Simulate Error" button
2. Find the error trace in Tempo
3. Examine the span with error status

**Tasks**:
- What's the error message?
- What span recorded the exception?
- Find the correlated log entry
- Identify the line of code that failed

**Hint**: Look at span events and exception details

---

### Exercise 4: Calculate Error Budget

**Objective**: Understand SLO math and error budgets

**Scenario**: Your SLO is 99.9% availability over 30 days

1. Total time: 30 days = 43,200 minutes
2. Error budget: 0.1% = 43.2 minutes

**Exercise**:
1. Generate 1000 requests (use bulk task creation multiple times)
2. Simulate 5 errors
3. Calculate actual availability:
   ```
   (1000 - 5) / 1000 = 99.5%
   ```
4. Did you breach SLO?
5. How much error budget remains?

---

### Exercise 5: Service Dependency Mapping

**Objective**: Visualize service relationships

1. Generate various types of requests
2. Navigate to **End-to-End Tracing Dashboard**
3. View the **Service Dependency Map**

**Observe**:
- Services in your architecture
- Request rates between services
- Error rates on connections
- Latency on each edge

---

## Troubleshooting

### Traces Not Appearing

**Check 1: OTEL Collector Health**
```bash
curl http://localhost:13133
# Should return healthy status
```

**Check 2: Backend Sending Traces**
```bash
docker compose logs backend | grep -i trace
```

**Check 3: Tempo Receiving Data**
```bash
curl http://localhost:3200/api/search
```

**Fix**: Restart services
```bash
docker compose restart otel-collector backend
```

---

### Metrics Not Showing in Grafana

**Check 1: Prometheus Targets**
1. Open http://localhost:9090/targets
2. All targets should be "UP"

**Check 2: OTEL Collector Metrics Endpoint**
```bash
curl http://localhost:8889/metrics
```

**Check 3: Query Prometheus**
```bash
curl 'http://localhost:9090/api/v1/query?query=http_requests_total'
```

---

### Logs Missing

**Check Loki**:
```bash
curl http://localhost:3100/ready
```

**Query Logs**:
```bash
# Check available labels
curl -s "http://localhost:3100/loki/api/v1/labels" | jq

# Query logs by service_name
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={service_name="flask-backend"}' | jq
```

**Available Loki Labels** (after attribute hints configuration):
- `service_name` - Service identifier
- `service_instance_id` - Container ID
- `deployment_environment` - Environment (lab, dev, prod)
- `level` - Log level (INFO, ERROR, etc.)
- `exporter` - OTLP exporter
- `instance` - Instance hostname
- `job` - Job name

---

### Frontend Not Loading

**Check 1: Frontend Container**
```bash
docker compose logs frontend
```

**Check 2: CORS Issues**
- Open browser console (F12)
- Look for CORS errors
- Verify OTEL Collector CORS config

**Fix**: Rebuild frontend
```bash
docker compose up -d --force-recreate frontend
```

---

## Advanced Topics

### Custom Instrumentation

Add your own spans to the Flask backend:

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

@app.route('/api/custom')
def custom_endpoint():
    with tracer.start_as_current_span("custom_operation") as span:
        span.set_attribute("custom.attribute", "value")
        # Your business logic
        return jsonify({"status": "ok"})
```

### Adding Custom Metrics

```python
from opentelemetry import metrics

meter = metrics.get_meter(__name__)
custom_counter = meter.create_counter(
    name="custom_events_total",
    description="Count of custom events"
)

custom_counter.add(1, {"event_type": "user_action"})
```

### TraceQL Queries

Powerful trace searching in Grafana:

```traceql
# Find slow database queries
{span.db.query.duration > 50ms}

# Find errors in specific endpoint
{span.http.route = "/api/tasks" && status = error}

# Find traces with specific attribute
{span.task.completed = true}

# Complex query
{duration > 500ms && span.http.status_code >= 500}
```

---

## Key Takeaways

### 1. Observability != Monitoring
- **Monitoring**: Known unknowns (dashboards, alerts)
- **Observability**: Unknown unknowns (ad-hoc queries, exploration)

### 2. Three Pillars Work Together
- **Traces**: Show the path and timing
- **Metrics**: Show the trends and aggregates
- **Logs**: Show the details and context

### 3. Context is Everything
- Trace IDs correlate across pillars
- Span context propagates across services
- Structured data enables powerful queries

### 4. SLIs Drive SRE Practice
- Measure what users care about
- Error budgets enable risk-taking
- Data-driven decision making

### 5. Instrumentation Strategy
- Automatic instrumentation: Quick start
- Manual spans: Business-specific insights
- Custom metrics: Domain-specific SLIs

---

## Next Steps

### Extend the Lab

1. **Add Authentication**
   - Instrument login flows
   - Track user sessions in spans
   - Monitor authentication failures

2. **Implement Caching**
   - Add Redis cache layer
   - Instrument cache hits/misses
   - Measure cache effectiveness

3. **Add Message Queue**
   - Introduce async processing
   - Trace across message boundaries
   - Monitor queue depth and lag

4. **Multi-Service Architecture**
   - Split into microservices
   - Implement service mesh
   - Trace across service boundaries

### Production Considerations

1. **Sampling**
   - Implement tail-based sampling
   - Reduce trace volume
   - Preserve interesting traces

2. **Security**
   - Sanitize sensitive data
   - Implement RBAC in Grafana
   - Secure OTLP endpoints

3. **Scalability**
   - Use Tempo S3 backend
   - Scale Prometheus with Thanos
   - Implement Loki distributed mode

4. **Cost Optimization**
   - Set retention policies
   - Optimize cardinality
   - Sample low-value data

---

## Resources

### Documentation
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/)
- [Prometheus](https://prometheus.io/docs/)
- [Loki](https://grafana.com/docs/loki/)

### Books
- "Observability Engineering" by Charity Majors
- "Site Reliability Engineering" by Google
- "Distributed Tracing in Practice" by Austin Parker

### Community
- [CNCF Slack #opentelemetry](https://cloud-native.slack.com/)
- [Grafana Community Forums](https://community.grafana.com/)

---

## License

This lab is for educational purposes. Feel free to modify and extend for your learning journey.

---

## Additional Documentation

This lab includes comprehensive documentation for different learning paths:

### 📚 **Core Documentation**

1. **README.md** (this file) - ~850 lines
   - Complete walkthrough and exercises
   - Quick start and teardown instructions
   - Lab exercises and troubleshooting

2. **QUICK-REFERENCE.md** - ~430 lines
   - Cheat sheet for common commands
   - PromQL, TraceQL, and LogQL query examples
   - Quick troubleshooting tips

3. **PROJECT-SUMMARY.md** - ~580 lines
   - High-level project overview
   - Architecture components and features
   - Technology stack and versions
   - Success metrics and next steps

4. **DATA-FLOW.md** - ~500 lines
   - Visual data flow documentation
   - Request journey diagrams
   - Trace hierarchy examples
   - Correlation workflows

### 📖 **Advanced Documentation**

5. **IMPLEMENTATION-GUIDE.md** - ~2,200 lines (47,000+ words!)
   - **Complete technical deep-dive**
   - Every configuration explained in detail
   - All 6 troubleshooting scenarios with:
     - Full error messages and stack traces
     - Root cause analysis
     - Multiple attempted solutions
     - Final fixes with explanations
   - CI/CD integration patterns (Jenkins, GitLab CI, GitHub Actions)
   - Production readiness checklist
   - Performance tuning guide
   - Security considerations

6. **BLOG-POST.md** - ~1,100 lines (6,100+ words)
   - **The journey from clueless to confident**
   - Personal narrative of building the lab
   - Trial and error stories (falling forward)
   - Lessons learned from each issue
   - Meta-lessons about learning and AI pair programming
   - Perfect for blog publication

### 🎯 **Which Document Should I Read?**

**If you want to...**
- **Get started quickly** → README.md (this file) + QUICK-REFERENCE.md
- **Understand the architecture** → PROJECT-SUMMARY.md + DATA-FLOW.md
- **Troubleshoot issues** → IMPLEMENTATION-GUIDE.md
- **Learn from mistakes** → BLOG-POST.md
- **Integrate with CI/CD** → IMPLEMENTATION-GUIDE.md (CI/CD section)
- **Deploy to production** → IMPLEMENTATION-GUIDE.md (Production section)

**Total Documentation**: **5,580+ lines** covering theory, practice, and real-world troubleshooting.

---

## CI/CD Integration

This lab is **production-ready** and includes examples for:
- ✅ **Jenkins Pipeline** - Full Groovy pipeline with automated testing
- ✅ **GitLab CI** - YAML pipeline configuration
- ✅ **GitHub Actions** - Workflow for automated validation
- ✅ **SLI/SLO Enforcement** - Fail builds on SLO breaches
- ✅ **Performance Regression Detection** - Compare latency across builds
- ✅ **Dashboard Export** - Version control your Grafana dashboards

See **IMPLEMENTATION-GUIDE.md** for complete pipeline examples and integration patterns.

---

## Version History

- **v2.0** (October 13, 2025) - Battle-tested version
  - Upgraded OTel Collector to v0.96.0
  - Added Loki label configuration with attribute hints
  - Fixed all 6 major issues (documented in IMPLEMENTATION-GUIDE.md)
  - Added comprehensive documentation (5,580+ lines)
  - CI/CD integration examples

- **v1.0** (October 11, 2025) - Initial release
  - Complete observability stack
  - Basic documentation
  - Working examples

---

## Feedback

Found issues or have suggestions? This is a learning lab - experiment, break things, and learn!

For detailed troubleshooting of common issues, see **IMPLEMENTATION-GUIDE.md**.

---

**Created**: October 11, 2025
**Updated**: October 13, 2025
**Version**: 2.0 (Battle-Tested)
**Status**: Production-Ready for Learning ✅

**Happy Observing!** 🔭📊🚀
