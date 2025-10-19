# Post-Deployment Verification Checklist

**Purpose:** Verify that Option A implementation (single-source metrics) is working correctly after deployment to the VM.

**Last Updated:** 2025-10-19

---

## Pre-Deployment

### 1. Deploy All Changes

```bash
# Run your Jenkins pipeline OR manually deploy:
# (Assumes you have docker context configured: docker context create vm-lab ...)

# Sync files to VM
rsync -avz --delete \
  /path/to/Opentelemetry_Observability_Lab/ \
  user@192.168.122.250:/home/deploy/lab/app/

# SSH to VM and redeploy
ssh user@192.168.122.250
cd /home/deploy/lab/app
docker compose -p lab down
docker compose -p lab up -d --build

# Wait for services to start (30-60 seconds)
sleep 60
```

---

## Verification Tests

### Test 1: Verify Single Metric Source (Critical)

**What we're checking:** Prometheus should see `http_requests_total` from ONLY ONE job (flask-backend)

**Steps:**

```bash
# Option A: Via Prometheus UI
# Open: http://192.168.122.250:9090/graph
# Query:
count by (__name__, job) (http_requests_total)

# Expected Output:
# http_requests_total{job="flask-backend"} = 1

# Option B: Via command line
curl -s 'http://192.168.122.250:9090/api/v1/query?query=count%20by%20(__name__,%20job)%20(http_requests_total)' | jq .

# Expected JSON:
# {
#   "data": {
#     "result": [
#       {
#         "metric": {
#           "__name__": "http_requests_total",
#           "job": "flask-backend"
#         },
#         "value": [timestamp, "1"]
#       }
#     ]
#   }
# }
```

**Pass Criteria:**
- ✅ Exactly ONE result with `job="flask-backend"`
- ❌ If you see TWO results (flask-backend + otel-collector-prometheus-exporter), deployment failed

---

### Test 2: Flask /metrics Endpoint Works

**What we're checking:** Prometheus client library is exposing metrics correctly

**Steps:**

```bash
curl -s http://192.168.122.250:5000/metrics | head -50

# Expected Output (examples):
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
# http_requests_total{endpoint="get_tasks",method="GET",status_code="200"} 5.0
#
# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
# http_request_duration_seconds_bucket{endpoint="get_tasks",method="GET",status_code="200",le="0.005"} 3.0
# ...
#
# HELP http_errors_total Total HTTP errors
# TYPE http_errors_total counter
# http_errors_total{endpoint="unknown",method="GET",status_code="404"} 2.0
```

**Pass Criteria:**
- ✅ All three metrics present: `http_requests_total`, `http_request_duration_seconds`, `http_errors_total`
- ✅ Labels include: `method`, `endpoint`, `status_code`
- ✅ Values are numeric (not NaN or empty)

---

### Test 3: Generate Traffic & Verify Prometheus Ingestion

**What we're checking:** Prometheus is scraping Flask and storing metrics

**Steps:**

```bash
# Generate some traffic
for i in {1..10}; do
  curl -s http://192.168.122.250:8080/ > /dev/null
  curl -s http://192.168.122.250:8080/api/tasks > /dev/null
  sleep 1
done

# Wait for Prometheus to scrape (15s interval)
sleep 20

# Query Prometheus for recent data
curl -s 'http://192.168.122.250:9090/api/v1/query?query=rate(http_requests_total%5B1m%5D)' | jq '.data.result[] | {endpoint: .metric.endpoint, rate: .value[1]}'

# Expected Output:
# {
#   "endpoint": "get_tasks",
#   "rate": "0.033333"  // Non-zero value
# }
```

**Pass Criteria:**
- ✅ `rate()` query returns non-zero values
- ✅ Multiple endpoints visible (if you hit different routes)

---

### Test 4: Grafana Datasource Health

**What we're checking:** Grafana can connect to all datasources

**Steps:**

1. Open Grafana: `http://192.168.122.250:3000`
2. Navigate to: **Connections** → **Data sources**
3. Click on each datasource and click **Test** button:

**Prometheus:**
- URL: `http://prometheus:9090`
- Status: ✅ **"Data source is working"**

**Tempo:**
- URL: `http://tempo:3200`
- Status: ✅ **"Data source is working"**

**Loki:**
- URL: `http://loki:3100`
- Status: ✅ **"Data source is working"**

**Pass Criteria:**
- ✅ All three datasources show green "working" status
- ❌ If any show red/error, check network connectivity and service logs

---

### Test 5: Grafana Explore - Prometheus Queries

**What we're checking:** Grafana can query Prometheus metrics successfully

**Steps:**

1. Open: `http://192.168.122.250:3000/explore`
2. Select datasource: **Prometheus**
3. Run these queries:

**Query 1: Basic metric existence**
```promql
http_requests_total
```
**Expected:** Time-series graph with lines (after generating traffic)

**Query 2: Rate calculation (SLI-style)**
```promql
rate(http_requests_total[5m])
```
**Expected:** Smoothed rate graph

**Query 3: Error rate**
```promql
rate(http_errors_total[5m]) / rate(http_requests_total[5m]) * 100
```
**Expected:** Percentage graph (should be low/zero if no errors)

**Pass Criteria:**
- ✅ All queries return data (not "No data")
- ✅ Time range: "Last 1 hour" shows activity after traffic generation
- ✅ Metrics have proper labels: `endpoint`, `method`, `status_code`

---

### Test 6: SLI/SLO Dashboard Functionality

**What we're checking:** All dashboard panels populate with real data

**Steps:**

1. Open: `http://192.168.122.250:3000/d/sli-slo-dashboard/sli-slo-dashboard-task-manager`
2. Verify each panel:

**Panel: "Service Availability (SLI)"**
- Should show: **~100%** (green gauge) if no errors
- Formula: `100 * (1 - (errors / requests))`

**Panel: "P95 Response Time (SLI)"**
- Should show: **< 1s** (green/yellow gauge)
- Formula: `histogram_quantile(0.95, ...)`

**Panel: "Request Rate by Endpoint"**
- Should show: **Lines for each endpoint** (get_tasks, create_task, etc.)
- Formula: `rate(http_requests_total[1m]) by (endpoint)`

**Panel: "Error Rate by Endpoint (%)"**
- Should show: **0% or low %** (if no errors)
- Formula: `100 * (errors / requests) by (endpoint)`

**Panel: "Response Time Percentiles"**
- Should show: **P50, P95, P99 lines**
- Formula: `histogram_quantile(...)`

**Panel: "Database Query P95 Latency"**
- **May show "No data"** - This is OK! We removed OTel metrics, so `database_query_duration_seconds` is no longer exported to Prometheus (only used in span attributes)
- **Workaround:** Query Tempo spanmetrics instead (future enhancement)

**Panel: "Requests by Status Code"**
- Should show: **Bar chart with 200, 201, 404, etc.**
- Formula: `rate(http_requests_total[5m]) by (status_code)`

**Pass Criteria:**
- ✅ 6 out of 7 panels show data
- ⚠️ "Database Query P95 Latency" may be empty (expected after Option A)
- ❌ If all panels say "No data", check datasource UID and Prometheus scraping

---

### Test 7: Traces Still Work (OTel → Tempo)

**What we're checking:** Despite removing OTel metrics, traces still flow to Tempo

**Steps:**

1. Generate activity with trace creation:
```bash
# Create a task (triggers trace)
curl -X POST http://192.168.122.250:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Test trace", "description": "Verification test"}'
```

2. Open Grafana Explore: `http://192.168.122.250:3000/explore`
3. Select datasource: **Tempo**
4. Search:
   - Service: `flask-backend`
   - Time range: Last 15 minutes
   - Click **Run query**

**Expected Output:**
- ✅ List of traces appears
- ✅ Click a trace → see spans:
  - `POST /api/tasks` (root span)
  - `create_task` (child span)
  - `INSERT /app/data/tasks.db` (SQLAlchemy span)

**Pass Criteria:**
- ✅ Traces are present and complete with all spans
- ✅ Span attributes include `http.method`, `http.target`, `db.statement`
- ❌ If no traces, check `docker logs otel-collector` and `docker logs tempo`

---

### Test 8: Logs with Trace Correlation (OTel → Loki)

**What we're checking:** Logs flow to Loki with trace_id for correlation

**Steps:**

1. Open Grafana Explore: `http://192.168.122.250:3000/explore`
2. Select datasource: **Loki**
3. Query:
```logql
{service_name="flask-backend"} |= "Request completed"
```

**Expected Output:**
- ✅ Log lines appear with JSON structure
- ✅ Each line includes:
  - `trace_id`: e.g., `"trace_id": "3a7f2b..."`
  - `span_id`: e.g., `"span_id": "8c1d..."`
  - `method`: `"GET"`, `"POST"`, etc.
  - `status_code`: `200`, `201`, `404`, etc.

**Advanced Test: Trace → Log Correlation**

1. In Tempo Explore, click a trace
2. In the trace view, find the `trace_id` value
3. Click **"Logs for this span"** button (if available)
4. **Should jump to Loki** with logs filtered by that trace_id

**Pass Criteria:**
- ✅ Logs appear in Loki with trace context
- ✅ Trace → Log navigation works (if configured in datasource)
- ❌ If no logs, check `docker logs otel-collector` and `docker logs loki`

---

### Test 9: Tempo Spanmetrics (Bonus - Verify No Conflict)

**What we're checking:** Tempo-generated spanmetrics are still in Prometheus (different from app metrics)

**Steps:**

```bash
# Query Tempo-generated metrics
curl -s 'http://192.168.122.250:9090/api/v1/query?query=traces_spanmetrics_calls_total' | jq '.data.result[0].metric'

# Expected Output:
# {
#   "__name__": "traces_spanmetrics_calls_total",
#   "cluster": "docker-compose",
#   "service": "flask-backend",
#   "source": "tempo",
#   "span_kind": "SPAN_KIND_SERVER",
#   "span_name": "/api/tasks",
#   "status_code": "STATUS_CODE_UNSET",
#   ...
# }
```

**Pass Criteria:**
- ✅ `traces_spanmetrics_calls_total` exists
- ✅ Has `source="tempo"` label (different from app metrics)
- ✅ No conflict with `http_requests_total` (different metric name)

**Note:** These metrics are derived from traces and complement (not duplicate) your app metrics.

---

### Test 10: Frontend Observability Links

**What we're checking:** Dynamic links work across environments

**Steps:**

1. Open: `http://192.168.122.250:8080/`
2. Scroll to bottom: **"Observability Dashboards"** section
3. Click each link and verify it opens correctly:

**Grafana:**
- Link: `http://192.168.122.250:3000`
- Should open: Grafana home page ✅

**Prometheus:**
- Link: `http://192.168.122.250:9090`
- Should open: Prometheus graph page ✅

**Tempo:**
- Link: `http://192.168.122.250:3200`
- Should open: Tempo status page or Grafana Tempo datasource ✅

**Collector Metrics:**
- Link: `http://192.168.122.250:8888/metrics`
- Should open: OTel Collector internal metrics (plain text) ✅

**Pass Criteria:**
- ✅ All links use VM IP (`192.168.122.250`), not `localhost`
- ✅ Links open to correct services (no 404s)

---

## Troubleshooting

### Issue: "No data" in SLI Dashboard

**Diagnosis:**
```bash
# 1. Check Prometheus has data
curl -s 'http://192.168.122.250:9090/api/v1/query?query=http_requests_total' | jq .

# 2. Check Prometheus scrape targets
curl -s http://192.168.122.250:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="flask-backend")'

# 3. Check Grafana datasource UID
docker exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml | grep -A5 Prometheus
```

**Solution:**
- If Prometheus has no data: Check Flask is running and `/metrics` works
- If scrape target is down: Check `docker ps` and network connectivity
- If datasource UID wrong: Update `datasources.yml` and restart Grafana

---

### Issue: Duplicate Metrics Still Appear

**Diagnosis:**
```bash
count by (__name__, job) (http_requests_total)
# If result shows TWO jobs, collector exporter still running
```

**Solution:**
```bash
# On VM:
docker compose -p lab down
docker compose -p lab up -d --build

# Verify collector config
docker exec otel-collector cat /etc/otel-collector-config.yml | grep -A10 "metrics:"
# Should show: "# Metrics pipeline removed"
```

---

### Issue: Traces Not Appearing in Tempo

**Diagnosis:**
```bash
# Check collector logs
docker logs otel-collector 2>&1 | grep -i "error\|fail"

# Check Tempo logs
docker logs tempo 2>&1 | grep -i "error\|fail"

# Verify OTLP endpoint reachable
docker exec flask-backend nc -zv otel-collector 4318
```

**Solution:**
- Check collector `receivers.otlp.protocols.http.endpoint: 0.0.0.0:4318`
- Check Flask `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318`
- Restart collector and backend

---

### Issue: Logs Missing in Loki

**Diagnosis:**
```bash
# Check if logs are being sent
docker logs otel-collector 2>&1 | grep "loki"

# Check Loki ingestion
curl -s http://192.168.122.250:3100/ready
# Should return: "ready"

# Query Loki directly
curl -G -s 'http://192.168.122.250:3100/loki/api/v1/query' \
  --data-urlencode 'query={service_name="flask-backend"}' | jq .
```

**Solution:**
- Check Loki is running: `docker ps | grep loki`
- Check collector → Loki connection in collector logs
- Verify `exporters.loki.endpoint: http://loki:3100/loki/api/v1/push`

---

## Success Criteria Summary

| Test | Expected Result | Status |
|------|----------------|--------|
| 1. Single metric source | ✅ Only `job="flask-backend"` | ☐ |
| 2. /metrics endpoint | ✅ All 3 metrics present | ☐ |
| 3. Prometheus ingestion | ✅ Non-zero rate values | ☐ |
| 4. Datasource health | ✅ All 3 datasources green | ☐ |
| 5. Explore queries | ✅ Metrics return data | ☐ |
| 6. SLI dashboard | ✅ 6/7 panels populated | ☐ |
| 7. Traces in Tempo | ✅ Spans visible with hierarchy | ☐ |
| 8. Logs in Loki | ✅ Logs with trace_id | ☐ |
| 9. Spanmetrics | ✅ `source="tempo"` metrics | ☐ |
| 10. Frontend links | ✅ All links work | ☐ |

**Overall Pass:** All critical tests (1-8) must pass. Tests 9-10 are bonus validation.

---

## Final Validation

After completing all tests:

```bash
# Create a comprehensive activity log
echo "=== Final Verification ===" > /tmp/verification.log
echo "Date: $(date)" >> /tmp/verification.log
echo "" >> /tmp/verification.log

echo "Prometheus Targets:" >> /tmp/verification.log
curl -s http://192.168.122.250:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .labels.job, health: .health}' \
  >> /tmp/verification.log

echo "" >> /tmp/verification.log
echo "Metric Counts:" >> /tmp/verification.log
curl -s 'http://192.168.122.250:9090/api/v1/query?query=count(http_requests_total)' | \
  jq '.data.result[0].value[1]' >> /tmp/verification.log

echo "" >> /tmp/verification.log
echo "Service Status:" >> /tmp/verification.log
docker --context vm-lab compose -p lab ps >> /tmp/verification.log

cat /tmp/verification.log
```

**System is production-ready when:**
- ✅ All services show `Up` status
- ✅ Prometheus has >0 targets healthy
- ✅ Metrics count > 0
- ✅ SLI dashboard fully functional
- ✅ Traces and logs flow correctly

---

**Document Version:** 1.0
**Last Verified:** [Fill in after successful deployment]
**Verified By:** [Your name]
