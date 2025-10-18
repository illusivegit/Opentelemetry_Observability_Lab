# OpenTelemetry Observability Lab - Project Summary

## What We've Built

A complete, production-grade observability stack for learning distributed tracing, metrics collection, and log aggregation using OpenTelemetry. This lab has been battle-tested through real troubleshooting scenarios and is ready for CI/CD integration.

---

## Architecture Components

### Application Stack
1. **Frontend** (HTML/CSS/JavaScript)
   - Task management UI
   - OpenTelemetry Browser SDK integration
   - Automatic fetch/XHR instrumentation
   - Custom span creation for user interactions
   - Real-time telemetry to OTLP collector

2. **Backend** (Flask/Python)
   - RESTful API with CRUD operations
   - SQLAlchemy ORM
   - Comprehensive OpenTelemetry instrumentation
   - Structured JSON logging with trace correlation
   - Custom metrics for SLI tracking
   - OTLP export for traces, metrics, and logs

3. **Database** (SQLite)
   - Task persistence with named volume
   - Fully instrumented queries
   - Query performance tracking
   - Connection and transaction monitoring

### Observability Stack
1. **OpenTelemetry Collector (v0.96.0)**
   - OTLP receiver (HTTP + gRPC)
   - Advanced data processing pipeline
   - Memory-limited for stability
   - Multi-backend exporters
   - Attribute hints for Loki label promotion
   - Health check and debug extensions

2. **Grafana Tempo (2.3.1)**
   - Distributed trace storage
   - TraceQL query engine
   - Service dependency mapping
   - Trace-to-log correlation

3. **Prometheus (2.48.1)**
   - Metrics storage and querying
   - Remote write receiver enabled
   - SLI/SLO calculations
   - Alert rule support (ready to deploy)
   - Scrapes collector internal metrics

4. **Grafana Loki (2.9.3)**
   - Log aggregation with label-based indexing
   - Trace-log correlation via derived fields
   - LogQL query language
   - Automatic service_name label extraction

5. **Grafana (10.2.3)**
   - Unified visualization platform
   - Pre-built dashboards (SLI/SLO, End-to-End Tracing)
   - Cross-signal correlation (Traces → Logs → Metrics)
   - Auto-provisioned datasources

---

## Key Features

### End-to-End Tracing
✅ Browser → Backend → Database correlation
✅ W3C Trace Context propagation across services
✅ Parent-child span relationships
✅ Exception tracking and error propagation
✅ Custom span attributes and events
✅ Automatic + manual instrumentation

### Metrics & SLIs
✅ Request rate (throughput)
✅ Error rate (reliability)
✅ Latency percentiles (p50, p95, p99)
✅ Database query performance
✅ Custom business metrics
✅ Real-time SLO compliance
✅ Error budget tracking

### Log Aggregation
✅ Structured JSON logging
✅ Trace ID correlation (every log linked to trace)
✅ Multi-level logging (INFO, ERROR, etc.)
✅ Contextual metadata
✅ Log-to-trace navigation in Grafana
✅ Service name labels for filtering

### SLI/SLO Implementation
✅ Availability SLI: >99% uptime target
✅ Latency SLI: p95 < 500ms target
✅ Error budget tracking and visualization
✅ Real-time dashboards
✅ Alerting rules (ready to deploy)

### Advanced Correlation
✅ "Logs for this span" - Jump from trace to related logs
✅ "Trace ID" links in logs - Jump from log to full trace
✅ Exemplars in metrics - Jump from latency spike to slow trace
✅ Service dependency mapping

---

## Project Structure

```
otel-observability-lab/
├── backend/
│   ├── app.py                 # Flask app with full OTEL instrumentation
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile             # Container image definition
│
├── frontend/
│   ├── index.html             # Task Manager UI
│   ├── styles.css             # Modern, responsive styling
│   ├── app.js                 # Application logic + manual tracing
│   └── otel-browser.js        # Browser SDK configuration
│
├── otel-collector/
│   ├── otel-collector-config.yml  # Main collector configuration (v0.96.0)
│   ├── tempo.yml                  # Tempo backend config
│   ├── loki-config.yml            # Loki backend config
│   └── prometheus.yml             # Prometheus scrape config
│
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml    # Auto-configured datasources with UIDs
│   │   └── dashboards/
│   │       └── dashboard-provider.yml
│   └── dashboards/
│       ├── sli-slo-dashboard.json      # SLI/SLO metrics
│       └── end-to-end-tracing.json     # Tracing & logs
│
├── docker-compose.yml        # Full stack orchestration
├── start-lab.sh              # Quick start script
├── .gitignore                # Git ignore rules
├── README.md                 # Complete documentation
├── QUICK-REFERENCE.md        # Cheat sheet for commands/queries
├── DATA-FLOW.md              # Visual data flow documentation
├── PROJECT-SUMMARY.md        # This file
├── IMPLEMENTATION-GUIDE.md   # Technical deep-dive (47,000+ words)
└── BLOG-POST.md              # Journey blog post (6,100+ words)
```

---

## Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Frontend | HTML5/CSS3/JS | - | User interface |
| Frontend SDK | OpenTelemetry Browser | 1.19.0 | Client-side tracing |
| Backend | Flask | 3.0.0 | API server |
| Backend SDK | OpenTelemetry Python | 1.22.0 | Server-side instrumentation |
| ORM | SQLAlchemy | 3.1.1 | Database abstraction |
| Database | SQLite | 3 | Data persistence |
| Collector | OTEL Collector Contrib | **0.96.0** | Telemetry pipeline |
| Tracing | Grafana Tempo | 2.3.1 | Trace storage |
| Metrics | Prometheus | 2.48.1 | Metrics storage |
| Logs | Grafana Loki | 2.9.3 | Log aggregation |
| Visualization | Grafana | 10.2.3 | Dashboards & UI |
| Container | Docker | 20.10+ | Containerization |
| Orchestration | Docker Compose | 2.0+ | Service orchestration |

---

## What You Can Learn

### For DevOps/SRE Engineers
- Implementing observability in production systems
- Setting up OpenTelemetry from scratch
- Defining and tracking SLIs/SLOs with error budgets
- Debugging distributed systems with traces
- Creating operational dashboards
- Troubleshooting telemetry pipelines
- CI/CD integration patterns

### For Developers
- Instrumenting applications with OpenTelemetry
- Understanding distributed tracing concepts
- Writing observable code with meaningful spans
- Performance optimization techniques
- Error tracking and root cause analysis
- Structured logging best practices

### For Security Engineers (DevSecOps)
- Monitoring application behavior for anomalies
- Detecting security incidents in traces
- Tracking authentication and authorization flows
- Identifying suspicious patterns in logs
- Compliance and audit logging
- Correlating security events across services

---

## Lab Exercises Included

1. **Basic Tracing** - Follow a request end-to-end through all layers
2. **Performance Analysis** - Identify bottlenecks using span duration
3. **Error Debugging** - Root cause analysis with trace + log correlation
4. **SLO Calculations** - Error budget math and compliance tracking
5. **Service Mapping** - Visualize dependencies and data flow
6. **Log Correlation** - Link traces to logs using trace IDs
7. **Custom Instrumentation** - Add your own spans and attributes
8. **Load Testing** - Observe system under stress with bulk operations
9. **Metric Queries** - PromQL practice for SLI/SLO queries
10. **TraceQL Queries** - Advanced trace searching and filtering

---

## Production-Ready Features

### Security
- CORS configuration for browser SDK
- No hardcoded secrets (environment-based config)
- Volume separation for data isolation
- TLS-ready configuration (disabled for lab)

### Scalability
- Batch processing in collector (10s batches)
- Memory limits configured (512MB)
- Configurable retention policies
- Ready for distributed deployment
- Horizontal scaling patterns documented

### Reliability
- Health check endpoints on all services
- Service dependencies properly managed
- Graceful degradation support
- Error handling throughout stack
- Automatic retry on failure

### Observability
- Self-monitoring enabled (collector exports its own metrics)
- Collector metrics exposed on port 8889
- Pipeline visibility with debug logging
- Extensions: health_check, pprof, zpages

---

## Deployment Options

### Local Development (Current Setup)
```bash
./start-lab.sh
```
All services run on localhost via Docker Compose. Perfect for learning and experimentation.

### CI/CD Integration
The lab includes Jenkins pipeline examples for:
- Automated telemetry validation
- SLI/SLO enforcement in builds
- Performance regression detection
- Dashboard export and versioning
- Log/trace artifact collection

Also compatible with:
- GitLab CI
- GitHub Actions
- CircleCI
- Travis CI

### Cloud Deployment (Production-Ready)
The architecture is ready for:
- **Kubernetes**: Helm charts can be generated from docker-compose
- **AWS**: ECS/Fargate + CloudWatch integration
- **GCP**: Cloud Run + Cloud Trace/Logging
- **Azure**: Container Instances + Application Insights

### Production Considerations
1. ✅ Replace SQLite with PostgreSQL/MySQL
2. ✅ Use Tempo with S3/GCS backend
3. ✅ Scale Prometheus with Thanos for long-term storage
4. ✅ Use Loki in distributed mode for high volume
5. ✅ Add authentication to Grafana (disable anonymous)
6. ✅ Implement tail-based sampling strategies
7. ✅ Set up alerting rules in Prometheus
8. ✅ Configure TLS for all OTLP endpoints
9. ✅ Implement PII sanitization in spans/logs
10. ✅ Use secrets manager for credentials

---

## Metrics Collected

### HTTP Metrics
- `http_requests_total` - Counter of all HTTP requests with labels (method, endpoint, status_code)
- `http_request_duration_seconds` - Histogram of request latency for percentile calculations
- `http_errors_total` - Counter of failed requests (status >= 400)

### Database Metrics
- `database_query_duration_seconds` - Histogram of query latency with operation type labels

### Labels/Attributes
All metrics include dimensional labels for filtering:
- `method` - HTTP method (GET, POST, PUT, DELETE)
- `endpoint` - API endpoint name
- `status_code` - HTTP response code
- `operation` - Database operation type (select, insert, update, delete)
- `table` - Database table name

---

## Traces Generated

### Span Types
1. **Browser Spans**
   - HTTP fetch requests (automatic)
   - User interactions (manual)
   - Performance timing

2. **HTTP Spans**
   - Incoming requests (Flask automatic)
   - Route handlers
   - Middleware operations

3. **Business Logic Spans**
   - create_task, update_task, delete_task, etc.
   - Custom operations
   - Validation steps

4. **Database Spans**
   - SQL queries (SQLAlchemy automatic)
   - Connections
   - Transactions

### Span Attributes (Examples)
- **HTTP**: `http.method`, `http.route`, `http.status_code`, `http.url`
- **Database**: `db.system`, `db.statement`, `db.name`, `db.operation`
- **Custom**: `task.id`, `task.title`, `task.completed`
- **Timing**: `db.query.duration`

---

## Logs Structure

### Log Format (JSON)
```json
{
  "timestamp": "2025-10-13T11:34:32.029Z",
  "name": "root",
  "level": "INFO",
  "message": "Created new task 6: Test task for label verification",
  "trace_id": "542b72fbc89a2f3193ad6a35e5bf6b39",
  "span_id": "e350cf8075afe40a",
  "service.name": "flask-backend",
  "method": "POST",
  "path": "/api/tasks"
}
```

### Log Levels
- **INFO**: Normal operations (request start/complete, task creation)
- **WARNING**: Potential issues (validation failures, not found)
- **ERROR**: Failures and exceptions (database errors, unhandled exceptions)

### Loki Labels (Automatically Extracted)
- `service_name` - Service identifier (flask-backend)
- `service_instance_id` - Container/instance ID
- `deployment_environment` - Environment (lab, dev, prod)
- `level` - Log level (INFO, ERROR, etc.)
- `exporter` - Telemetry exporter (OTLP)
- `instance` - Instance hostname
- `job` - Job name from Prometheus

---

## SLI/SLO Definitions

### Availability SLI
**Definition**: Percentage of successful HTTP requests
**Formula**: `(Total Requests - Error Requests) / Total Requests * 100`
**Prometheus Query**:
```promql
100 * (1 - (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))))
```
**Target SLO**: 99.9% (3 nines)
**Error Budget**: 0.1% = ~43 minutes downtime/month

### Latency SLI
**Definition**: 95th percentile request latency
**Formula**: `histogram_quantile(0.95, http_request_duration_seconds)`
**Prometheus Query**:
```promql
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```
**Target SLO**: < 500ms
**Compliance**: 95% of requests must meet target

### Database Performance SLI
**Definition**: 95th percentile query latency
**Formula**: `histogram_quantile(0.95, database_query_duration_seconds)`
**Prometheus Query**:
```promql
histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le))
```
**Target SLO**: < 100ms
**Compliance**: 95% of queries must meet target

---

## Getting Started in 3 Steps

```bash
# 1. Navigate to lab directory
cd otel-observability-lab

# 2. Start all services
./start-lab.sh

# 3. Open the frontend
http://localhost:8080
```

Then:
1. Create some tasks to generate telemetry
2. Open Grafana: http://localhost:3000 (anonymous login enabled)
3. Explore traces in Tempo datasource
4. Check logs in Loki with `{service_name="flask-backend"}`
5. View the SLI/SLO Dashboard for metrics

---

## Documentation Files

| File | Purpose | Length |
|------|---------|--------|
| **README.md** | Complete walkthrough & exercises | ~800 lines |
| **QUICK-REFERENCE.md** | Cheat sheet for commands/queries | ~430 lines |
| **DATA-FLOW.md** | Visual data flow documentation | ~500 lines |
| **PROJECT-SUMMARY.md** | This overview | ~550 lines |
| **IMPLEMENTATION-GUIDE.md** | Technical deep-dive with troubleshooting | ~2,200 lines |
| **BLOG-POST.md** | Journey from clueless to confident | ~1,100 lines |

**Total: 5,580+ lines** of comprehensive documentation covering theory, practice, and real troubleshooting experiences.

---

## Real-World Troubleshooting Experience

This lab was built through **trial and error**, documenting every issue encountered:

1. ✅ **Flask Application Context Error** - Solved by wrapping SQLAlchemy instrumentation in `app.app_context()`
2. ✅ **SQLite Database File Not Found** - Fixed with absolute paths and proper volume mounting
3. ✅ **Docker Build Cache Issues** - Learned when to use `--no-cache` flag
4. ✅ **Network DNS Resolution Failures** - Resolved with full `docker compose down && up`
5. ✅ **Logs Not Appearing in Loki** - Added complete OTLP Logs SDK to Flask app
6. ✅ **Loki Labels Missing** - Upgraded collector to v0.96.0 and used attribute hints

All troubleshooting steps, root causes, and solutions are documented in **IMPLEMENTATION-GUIDE.md**.

---

## Key Takeaways

1. **Observability ≠ Monitoring**
   - Monitoring: Known problems (dashboards, alerts)
   - Observability: Unknown problems (exploration, debugging)

2. **Three Pillars Work Together**
   - Traces show the path and timing
   - Metrics show the trends and aggregates
   - Logs show the details and context

3. **Context is Everything**
   - Trace IDs enable correlation across all three pillars
   - Structured data enables powerful queries
   - Metadata (labels/attributes) enables filtering

4. **SLIs Drive Decisions**
   - Measure what users care about (not just what's easy to measure)
   - Error budgets enable innovation (controlled risk-taking)
   - Data-driven improvements over gut feelings

5. **Automation is Key**
   - Auto-instrumentation gets you 80% there
   - Manual spans add critical business context
   - Both are necessary for complete visibility

6. **Versions Matter**
   - OpenTelemetry evolves rapidly (v0.91 → v0.96 had breaking changes)
   - Always check version-specific documentation
   - Test upgrades in non-production first

---

## Next Steps

### Extend the Lab
- Add authentication and track login flows with traces
- Implement Redis caching and measure hit rates
- Add message queue (RabbitMQ/Kafka) for async processing
- Split into microservices architecture
- Add frontend metrics (Web Vitals)

### Apply to Production
- Adapt for your specific tech stack
- Define your custom SLIs/SLOs based on user needs
- Set up alerting rules in Prometheus/AlertManager
- Train your team with this lab
- Implement sampling strategies to reduce costs

### Continue Learning
- Read "Observability Engineering" by Charity Majors
- Explore OpenTelemetry documentation for your language
- Join CNCF Slack #opentelemetry channel
- Contribute to open source observability projects
- Experiment with TraceQL and LogQL queries

---

## Success Metrics

After completing this lab, you should be able to:

✅ Explain distributed tracing concepts (spans, traces, context propagation)
✅ Implement OpenTelemetry in a full-stack application
✅ Define and track SLIs/SLOs with error budgets
✅ Debug performance issues using trace analysis
✅ Correlate traces, metrics, and logs for root cause analysis
✅ Write Prometheus (PromQL) and Tempo (TraceQL) queries
✅ Build and customize Grafana dashboards
✅ Understand observability best practices
✅ Troubleshoot telemetry pipeline issues
✅ Integrate observability into CI/CD pipelines

---

## CI/CD Integration

This lab is **CI/CD ready**. Example Jenkins pipeline included for:
- Automated lab startup and health checks
- Test traffic generation
- Telemetry validation (traces, metrics, logs)
- SLI/SLO compliance checks
- Performance regression detection
- Dashboard export as artifacts
- Automated cleanup

See **IMPLEMENTATION-GUIDE.md** for complete pipeline examples (Jenkins, GitLab CI, GitHub Actions).

---

## Support & Feedback

This is an educational lab designed for hands-on learning. Feel free to:
- Modify the code and experiment
- Break things intentionally to learn recovery
- Add new features and instrumentation
- Extend the architecture with new services
- Share your learnings with the community

**Remember**: The best way to learn observability is by observing real systems, including this lab itself!

---

## License

Educational use. Modify and extend as needed for your learning journey.

---

**Created**: October 11, 2025
**Updated**: October 13, 2025
**Version**: 2.0 (Battle-Tested)
**Status**: Production-Ready for Learning ✅
**Collector Version**: 0.96.0 (Latest Stable)

**Happy Observing!** 🔭📊🚀
