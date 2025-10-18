# Quick Reference Guide

## Starting the Lab

```bash
./start-lab.sh
# OR
docker compose up -d
```

## Stopping the Lab

```bash
docker compose down
# To remove volumes as well:
docker compose down -v
```

---

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:8080 | Task Manager UI |
| Grafana | http://localhost:3000 | Dashboards & Visualization |
| Prometheus | http://localhost:9090 | Metrics Storage |
| Tempo | http://localhost:3200 | Trace Storage |
| Loki | http://localhost:3100 | Log Storage |
| OTEL Collector | http://localhost:4318 | Telemetry Collection |
| Backend API | http://localhost:5000 | Flask API |

---

## Common Commands

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f otel-collector
docker compose logs -f grafana
```

### Restart Services
```bash
# All services
docker compose restart

# Specific service
docker compose restart backend
docker compose restart otel-collector
```

### Check Service Health
```bash
# OTEL Collector
curl http://localhost:13133

# Backend
curl http://localhost:5000/health

# Prometheus
curl http://localhost:9090/-/healthy

# Tempo
curl http://localhost:3200/ready

# Loki
curl http://localhost:3100/ready
```

---

## API Endpoints

### Task Management
```bash
# Get all tasks
curl http://localhost:5000/api/tasks

# Get specific task
curl http://localhost:5000/api/tasks/1

# Create task
curl -X POST http://localhost:5000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task","description":"Testing","completed":false}'

# Update task
curl -X PUT http://localhost:5000/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'

# Delete task
curl -X DELETE http://localhost:5000/api/tasks/1
```

### Testing Endpoints
```bash
# Simulate error
curl http://localhost:5000/api/simulate-error

# Simulate slow request (2 seconds)
curl http://localhost:5000/api/simulate-slow?delay=2

# Health check
curl http://localhost:5000/health
```

---

## Prometheus Queries

### Request Rate
```promql
# Total request rate
sum(rate(http_requests_total[5m]))

# Request rate by endpoint
sum(rate(http_requests_total[5m])) by (endpoint)

# Request rate by status code
sum(rate(http_requests_total[5m])) by (status_code)
```

### Error Rate
```promql
# Total error rate
sum(rate(http_errors_total[5m]))

# Error percentage
100 * (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m])))

# Error rate by endpoint
sum(rate(http_errors_total[5m])) by (endpoint)
```

### Latency
```promql
# P50 latency
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P95 latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Latency by endpoint
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))
```

### Database Metrics
```promql
# Database query duration P95
histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le))

# Query duration by operation
histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le, operation))
```

### SLI Calculations
```promql
# Availability SLI (percentage of successful requests)
100 * (1 - (sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))))

# Latency SLI (percentage of requests under 500ms)
100 * (
  sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m])) /
  sum(rate(http_request_duration_seconds_count[5m]))
)
```

---

## TraceQL Queries (Tempo)

### Basic Queries
```traceql
# All traces
{}

# Traces from specific service
{resource.service.name="flask-backend"}

# Traces with errors
{status=error}

# Slow traces (over 500ms)
{duration > 500ms}
```

### Advanced Queries
```traceql
# Errors in specific endpoint
{span.http.route="/api/tasks" && status=error}

# Slow database queries
{span.db.query.duration > 50ms}

# Traces with specific HTTP status
{span.http.status_code >= 500}

# Complex query
{resource.service.name="flask-backend" && duration > 1s && span.http.method="POST"}
```

---

## LogQL Queries (Loki)

### Basic Queries
```logql
# All logs from backend
{service_name="flask-backend"}

# Logs with specific level
{service_name="flask-backend"} |= "ERROR"

# Logs from specific endpoint
{service_name="flask-backend"} | json | endpoint="create_task"
```

### Advanced Queries
```logql
# Error logs with trace context
{service_name="flask-backend"} |= "ERROR" | json

# Logs with specific trace_id
{service_name="flask-backend"} | json | trace_id="abc123..."

# Rate of errors
sum(rate({service_name="flask-backend"} |= "ERROR" [5m]))
```

---

## Grafana Navigation

### Dashboards
1. Click **Dashboards** (four squares icon)
2. Select from:
   - **SLI/SLO Dashboard - Task Manager**
   - **End-to-End Tracing Dashboard**

### Explore
1. Click **Explore** (compass icon)
2. Select datasource:
   - **Prometheus**: Metrics
   - **Tempo**: Traces
   - **Loki**: Logs

### Correlating Data
1. In a trace view, click on a span
2. Click **Logs for this span** to see correlated logs
3. Click **Metrics** to see related metrics

---

## Troubleshooting

### No Traces Appearing
```bash
# Check OTEL Collector
docker compose logs otel-collector | grep -i error

# Check backend is sending traces
docker compose logs backend | grep -i trace

# Restart collector and backend
docker compose restart otel-collector backend
```

### Metrics Not Showing
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Check OTEL Collector metrics endpoint
curl http://localhost:8889/metrics

# Restart Prometheus
docker compose restart prometheus
```

### Logs Not Appearing
```bash
# Check Loki health
curl http://localhost:3100/ready

# Check OTEL Collector logs pipeline
docker compose logs otel-collector | grep -i loki

# Restart Loki
docker compose restart loki
```

### Frontend CORS Issues
```bash
# Check OTEL Collector CORS config
cat otel-collector/otel-collector-config.yml | grep -A 5 cors

# Check browser console for errors (F12)

# Restart frontend
docker compose restart frontend
```

### General Issues
```bash
# Check all container status
docker compose ps

# View resource usage
docker stats

# Rebuild everything
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

---

## File Structure

```
otel-observability-lab/
├── backend/
│   ├── app.py                    # Flask application with OTEL instrumentation
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile               # Backend container image
├── frontend/
│   ├── index.html               # Main UI
│   ├── styles.css               # Styling
│   ├── app.js                   # Application logic
│   └── otel-browser.js          # Browser OTEL instrumentation
├── otel-collector/
│   ├── otel-collector-config.yml # Collector configuration
│   ├── tempo.yml                # Tempo configuration
│   ├── loki-config.yml          # Loki configuration
│   └── prometheus.yml           # Prometheus configuration
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/         # Auto-configured datasources
│   │   └── dashboards/          # Dashboard provisioning
│   └── dashboards/
│       ├── sli-slo-dashboard.json        # SLI/SLO metrics dashboard
│       └── end-to-end-tracing.json       # Tracing dashboard
├── docker compose.yml           # Service orchestration
├── start-lab.sh                 # Quick start script
└── README.md                    # Full documentation
```

---

## Key Concepts

### Spans
- Represent a unit of work
- Have start time and duration
- Can have parent-child relationships
- Contain attributes (metadata)

### Traces
- Collection of spans representing a request
- Show the full path through your system
- Enable distributed debugging

### Metrics
- **Counter**: Monotonically increasing value
- **Histogram**: Distribution of values
- **Gauge**: Point-in-time value

### SLI (Service Level Indicator)
- Quantitative measure of service level
- Examples: availability, latency, throughput

### SLO (Service Level Objective)
- Target value/range for an SLI
- Example: "99.9% of requests succeed"

### Error Budget
- Amount of unreliability you can tolerate
- 100% - SLO = Error Budget
- Example: 99.9% SLO = 0.1% error budget

---

## Best Practices

1. **Always add context to spans**
   - Use meaningful span names
   - Add relevant attributes
   - Record exceptions properly

2. **Structure your logs**
   - Use JSON format
   - Include trace context
   - Use appropriate log levels

3. **Name metrics consistently**
   - Follow OpenTelemetry semantic conventions
   - Use clear, descriptive names
   - Add helpful labels

4. **Set realistic SLOs**
   - Based on user expectations
   - Measurable with your SLIs
   - Balance reliability vs innovation

5. **Use correlation**
   - Link traces to logs
   - Link traces to metrics
   - Use consistent service names

---

## Additional Resources

- OpenTelemetry Docs: https://opentelemetry.io/docs/
- Grafana Docs: https://grafana.com/docs/
- Prometheus Query Examples: https://prometheus.io/docs/prometheus/latest/querying/examples/
- TraceQL Documentation: https://grafana.com/docs/tempo/latest/traceql/
- LogQL Documentation: https://grafana.com/docs/loki/latest/logql/

---

**Quick Start**: `./start-lab.sh` → Open http://localhost:8080 → Create tasks → View in Grafana (http://localhost:3000)
