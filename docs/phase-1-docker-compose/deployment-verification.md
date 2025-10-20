# Deployment Verification Guide

This guide provides step-by-step verification procedures after deploying the observability lab to your VM.

## Pre-Deployment Checklist

Before deploying, ensure these configurations are correct:

### 1. Backend Configuration
- ✅ SQLAlchemy event listeners defined as **plain functions** (not decorators)
- ✅ Event listeners attached **inside** `with app.app_context():` block
- ✅ Functions defined **before** app context block
- ✅ Prometheus histogram name: `db_query_duration_seconds`

### 2. Nginx Configuration
- ✅ Docker DNS resolver: `resolver 127.0.0.11 ipv6=off valid=30s;`
- ✅ Variable-based proxy_pass: `set $backend_upstream http://backend:5000;`
- ✅ No URI suffix: `proxy_pass $backend_upstream;` (not `/api/`)

### 3. Docker Compose Configuration
- ✅ Service name: `backend` (matches Nginx target)
- ✅ Both `backend` and `frontend` on `otel-network`
- ✅ Backend healthcheck uses Python (available in python:3.11-slim)
- ✅ Frontend `depends_on` backend with `condition: service_healthy`

### 4. Prometheus Configuration
- ✅ Scrape target: `backend:5000` (matches service name)
- ✅ Job name: `flask-backend`

---

## Deployment Procedure

### Step 1: Clean Deployment

```bash
# On your VM (not dev host):
cd /home/deploy/lab/app

# Remove old containers and volumes
docker compose -p lab down -v

# Rebuild and start all services
docker compose -p lab up -d --build

# Wait for healthcheck to stabilize (15-20 seconds)
echo "Waiting for backend healthcheck..."
sleep 20
```

---

## Verification Steps

Run these commands **in order** on your VM. Each step must succeed before proceeding to the next.

### Step 2: Verify Backend Container Status

```bash
docker compose -p lab ps
```

**Expected output:**
```
NAME             IMAGE                      STATUS
flask-backend    ...                        Up (healthy)
frontend         nginx:alpine              Up
grafana          grafana/grafana:10.2.3    Up
...
```

**✅ Success criteria:**
- `backend` (flask-backend container) shows **"Up (healthy)"** status
- All other services show **"Up"** status

**❌ If backend shows "starting" or "unhealthy":**
```bash
# Check healthcheck logs
docker compose -p lab logs backend | tail -50

# Common issues:
# - Python healthcheck failing: Check if /metrics endpoint is accessible
# - App crash: Look for RuntimeError or import errors
```

---

### Step 3: Verify Backend Logs

```bash
docker compose -p lab logs backend | grep -E "Database initialized|event listeners registered"
```

**Expected output:**
```
flask-backend  | {"message": "Database initialized", ...}
flask-backend  | {"message": "SQLAlchemy event listeners registered for DB query duration tracking", ...}
```

**✅ Success criteria:**
- Both log messages present
- No RuntimeError or "Working outside of application context" errors

**❌ If messages missing:**
```bash
# View full backend logs
docker compose -p lab logs backend

# Look for:
# - RuntimeError: Working outside of application context
# - Import errors
# - SQLAlchemy errors
```

---

### Step 4: Verify DNS Resolution from Frontend

```bash
docker compose -p lab exec frontend getent hosts backend
```

**Expected output:**
```
172.18.0.X  backend
```

**✅ Success criteria:**
- Returns an IP address (172.18.0.X range)
- Service name "backend" resolves

**❌ If no output:**
- Backend container is not running or not on `otel-network`
- Check `docker compose -p lab ps` to ensure backend is up
- Verify both services are on same network:
  ```bash
  docker inspect -f '{{.Name}} -> {{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' \
    $(docker compose -p lab ps -q frontend backend)
  # Both should show same network ID
  ```

---

### Step 5: Verify API Connectivity from Frontend Container

```bash
docker compose -p lab exec frontend wget -qO- http://backend:5000/api/tasks
```

**Expected output:**
```json
[]
```
or a JSON array of tasks if you've created any.

**✅ Success criteria:**
- Returns valid JSON
- No "bad address" or connection errors

**❌ If fails:**
```bash
# Test if backend is listening
docker compose -p lab exec backend netstat -tlnp | grep 5000

# Test direct connection (bypass DNS)
docker compose -p lab exec frontend sh -c \
  'wget -qO- http://$(getent hosts backend | awk "{print \$1}"):5000/api/tasks'
```

---

### Step 6: Verify API Through Nginx Proxy (from VM Host)

```bash
curl http://192.168.122.250:8080/api/tasks
```

**Expected output:**
```json
[]
```

**✅ Success criteria:**
- Returns valid JSON
- HTTP 200 status (not 502 Bad Gateway)

**❌ If 502 error:**
```bash
# Check Nginx error logs
docker compose -p lab logs frontend | grep error

# Common error: "backend could not be resolved"
# → DNS issue, go back to Step 4

# Common error: "upstream prematurely closed connection"
# → Backend is crashing on requests, check backend logs
```

---

### Step 7: Verify Prometheus Metrics Endpoint

```bash
curl -s http://192.168.122.250:5000/metrics | head -20
```

**Expected output:**
```
# HELP python_gc_objects_collected_total Objects collected during gc
# TYPE python_gc_objects_collected_total counter
...
# HELP db_query_duration_seconds SQLite query duration in seconds
# TYPE db_query_duration_seconds histogram
db_query_duration_seconds_bucket{le="0.002",operation="SELECT"} 0.0
db_query_duration_seconds_bucket{le="0.005",operation="SELECT"} 0.0
...
```

**✅ Success criteria:**
- Returns Prometheus metrics in text format
- `db_query_duration_seconds_bucket` metrics present
- Histogram buckets visible with `operation` label

**❌ If no db_query metrics:**
- No DB queries have executed yet (normal on fresh deploy)
- Run Step 11 (DB smoke test) to generate traffic

---

### Step 8: Verify Prometheus Scrape Target Status

#### Option A: Web UI (Recommended)
1. Open browser: `http://192.168.122.250:9090/targets`
2. Find target: `flask-backend (backend:5000)`
3. Verify: **State = UP** (green background)
4. Check: Last scrape timestamp is recent (< 30 seconds ago)

#### Option B: Command Line
```bash
curl -s http://192.168.122.250:9090/api/v1/targets | \
  python3 -c "import sys, json; \
    targets = json.load(sys.stdin)['data']['activeTargets']; \
    flask = [t for t in targets if t['labels']['job'] == 'flask-backend'][0]; \
    print(f\"State: {flask['health']}\n Last Scrape: {flask['lastScrape']}\")"
```

**Expected output:**
```
State: up
Last Scrape: 2025-10-19T16:30:00.123Z
```

**✅ Success criteria:**
- `flask-backend` target shows **"up"** state
- Last scrape timestamp is recent

**❌ If target is "down":**
```bash
# Check if Prometheus can reach backend
docker compose -p lab exec prometheus wget -qO- http://backend:5000/metrics | head -5

# Verify Prometheus config has correct target
docker compose -p lab exec prometheus cat /etc/prometheus/prometheus.yml | grep -A 3 flask-backend
```

---

### Step 9: Verify Grafana Data Sources

1. Open browser: `http://192.168.122.250:3000`
2. Navigate: **Connections → Data Sources**
3. Click: **Prometheus**
4. Scroll down: Click **"Test"** button
5. Verify: **"Data source is working"** message appears (green)

Repeat for:
- **Tempo** data source
- **Loki** data source

**✅ Success criteria:**
- All three data sources show green "working" status

**❌ If any fail:**
- Check service is running: `docker compose -p lab ps`
- Verify network connectivity from Grafana container

---

### Step 10: Verify SLI/SLO Dashboard Panels

1. Open browser: `http://192.168.122.250:3000`
2. Navigate: **Dashboards → SLI/SLO Dashboard - Task Manager**
3. Wait: 30-60 seconds for panels to load

**Check these panels:**

| Panel Name | Expected State | Notes |
|------------|----------------|-------|
| **Request Rate** | Shows data (may be near 0) | Increments when you use the UI |
| **Error Rate** | Shows 0% or data | Will show errors if you click "Simulate Error" |
| **Request Duration P95** | Shows data | Latency histogram |
| **Database Query P95 Latency** | May show "No data" initially | Needs DB traffic (see Step 11) |
| **Active Tasks** | Shows 0 or count | Task count gauge |

**✅ Success criteria:**
- Request Rate panel shows lines (even if near 0)
- No "No data" errors on Request Rate/Duration panels
- Time series data visible for recent scrape intervals

**❌ If panels show "No data":**
```bash
# Generate some traffic to create metrics
curl http://192.168.122.250:8080/api/tasks
curl http://192.168.122.250:8080/api/tasks

# Wait 15-30 seconds for next Prometheus scrape
# Refresh Grafana dashboard
```

---

### Step 11: Generate DB Traffic (Warm P95 Latency Panel)

The "Database Query P95 Latency" panel requires DB query traffic to populate.

#### Option A: Web UI (Easiest)
1. Open browser: `http://192.168.122.250:8080`
2. Click: **"DB Smoke (warm P95)"** button
3. Wait: Toast notification says "DB smoke test completed"
4. Wait: 60-90 seconds for Prometheus to scrape new metrics
5. Refresh: Grafana dashboard
6. Verify: "Database Query P95 Latency" panel shows lines for SELECT/INSERT/UPDATE/DELETE

#### Option B: Command Line
```bash
# Send 300 mixed read/write operations
curl -X GET "http://192.168.122.250:8080/api/smoke/db?ops=300&type=rw"

# Wait for Prometheus scrape (15 second interval + processing)
sleep 90

# Check metrics are visible
curl -s http://192.168.122.250:5000/metrics | grep db_query_duration_seconds_bucket | grep -v "0.0$" | head -10
```

**Expected output (after 90 seconds):**
```
db_query_duration_seconds_bucket{le="0.002",operation="SELECT"} 150.0
db_query_duration_seconds_bucket{le="0.005",operation="SELECT"} 290.0
db_query_duration_seconds_bucket{le="0.002",operation="INSERT"} 50.0
...
```

**✅ Success criteria:**
- Grafana panel shows 4 lines (SELECT, INSERT, UPDATE, DELETE)
- P95 values are in milliseconds range (typically 5-50ms for SQLite)
- Lines show recent data points

---

### Step 12: Verify Tempo Traces (Optional)

1. Open browser: `http://192.168.122.250:3000`
2. Navigate: **Explore → Tempo**
3. Click: **"Search"** tab
4. Service Name: Select **"flask-backend"**
5. Click: **"Run Query"**
6. Click: Any trace ID to open trace details

**Check trace structure:**
```
GET /api/tasks
├─ GET (Flask handler)
│  └─ SELECT (SQLAlchemy query)
└─ ...
```

**✅ Success criteria:**
- Traces appear in search results
- Trace timeline shows Flask HTTP span
- Database query spans visible as children
- Span attributes include operation type (SELECT/INSERT/etc.)

---

## Troubleshooting Common Issues

### Issue 1: Backend shows "unhealthy" status

**Symptoms:**
```bash
docker compose -p lab ps
# flask-backend shows "Up (unhealthy)" or "starting"
```

**Diagnosis:**
```bash
# Check healthcheck command execution
docker compose -p lab exec backend python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/metrics', timeout=2).read()"
```

**Common causes:**
1. Flask app crashed → Check `docker compose -p lab logs backend` for errors
2. `/metrics` endpoint not responding → App may still be starting
3. Python import error → Verify `urllib.request` is available (should be in stdlib)

**Fix:**
```bash
# Wait longer for start_period (5 seconds)
sleep 10
docker compose -p lab ps

# If still unhealthy, check logs
docker compose -p lab logs backend | tail -100
```

---

### Issue 2: Nginx 502 "backend could not be resolved"

**Symptoms:**
```bash
curl http://192.168.122.250:8080/api/tasks
# Returns: 502 Bad Gateway

docker compose -p lab logs frontend | grep error
# Shows: backend could not be resolved (3: Host not found)
```

**Diagnosis:**
```bash
# Test DNS from frontend container
docker compose -p lab exec frontend getent hosts backend
# If no output → DNS problem
```

**Common causes:**
1. Backend container not running → `docker compose -p lab ps`
2. Backend not on otel-network → Check network config
3. Service name mismatch → Verify `backend` in docker-compose.yml

**Fix:**
```bash
# Restart frontend to re-resolve DNS
docker compose -p lab restart frontend

# Verify backend is up and healthy
docker compose -p lab ps | grep backend

# Check network membership
docker inspect -f '{{.Name}} -> {{range .NetworkSettings.Networks}}{{.Name}}{{end}}' \
  $(docker compose -p lab ps -q frontend backend)
```

---

### Issue 3: Grafana panels show "No data"

**Symptoms:**
- Dashboard panels are blank or show "No data" message
- Time range selector shows "Last 5 minutes" or similar

**Diagnosis:**
```bash
# Check Prometheus is scraping
curl -s http://192.168.122.250:9090/api/v1/targets | grep flask-backend

# Check metrics are being exported
curl -s http://192.168.122.250:5000/metrics | grep http_requests_total
```

**Common causes:**
1. No traffic generated yet → Use the UI to create requests
2. Prometheus target down → Check Step 8
3. Time range too narrow → Expand to "Last 15 minutes" in Grafana

**Fix:**
```bash
# Generate traffic
for i in {1..10}; do
  curl http://192.168.122.250:8080/api/tasks
  sleep 1
done

# Wait for scrape
sleep 20

# Refresh Grafana dashboard
# Expand time range to "Last 15 minutes"
```

---

### Issue 4: DB P95 Latency panel shows "No data"

**Symptoms:**
- Other panels work fine
- "Database Query P95 Latency" panel remains empty

**Diagnosis:**
```bash
# Check if histogram metrics exist
curl -s http://192.168.122.250:5000/metrics | grep db_query_duration_seconds_bucket
```

**Common causes:**
1. No DB queries executed yet → Histogram has no samples
2. Event listeners not registered → Check backend logs for "event listeners registered"
3. Metric name mismatch → Verify `db_query_duration_seconds` in code and dashboard

**Fix:**
```bash
# Verify event listeners are registered
docker compose -p lab logs backend | grep "event listeners registered"

# Generate DB traffic
curl "http://192.168.122.250:8080/api/smoke/db?ops=300&type=rw"

# Wait for Prometheus scrape
sleep 90

# Check histogram has data
curl -s http://192.168.122.250:5000/metrics | grep db_query_duration_seconds_bucket | grep -v "0.0$"

# Refresh Grafana panel
```

---

## Success Criteria Summary

All verification steps complete when:

- ✅ Backend container status: **"Up (healthy)"**
- ✅ Backend logs show: **"Database initialized"** and **"event listeners registered"**
- ✅ DNS resolution: `getent hosts backend` returns IP
- ✅ API from frontend container: Returns JSON (no errors)
- ✅ API through Nginx: Returns JSON (no 502 errors)
- ✅ Metrics endpoint: Returns Prometheus metrics with `db_query_duration_seconds`
- ✅ Prometheus target: **flask-backend** shows **"UP"** state
- ✅ Grafana data sources: All show **"Data source is working"**
- ✅ SLI/SLO panels: Show data (after generating traffic)
- ✅ DB P95 panel: Shows data (after DB smoke test)
- ✅ Tempo traces: Show DB query spans

---

## Appendix: Quick Health Check Script

Save this script on your VM for quick verification:

```bash
#!/bin/bash
# health-check.sh - Quick observability lab health check

echo "=== Observability Lab Health Check ==="
echo

echo "1. Container Status:"
docker compose -p lab ps | grep -E "(backend|frontend|prometheus|grafana)"
echo

echo "2. Backend Health:"
docker compose -p lab exec backend python -c "import urllib.request; print('✓ Healthcheck OK')" 2>&1 | head -1
echo

echo "3. DNS Resolution:"
docker compose -p lab exec frontend getent hosts backend | awk '{print "✓ backend →", $1}'
echo

echo "4. API Connectivity:"
curl -s -o /dev/null -w "✓ HTTP %{http_code}\n" http://192.168.122.250:8080/api/tasks
echo

echo "5. Prometheus Target:"
curl -s http://192.168.122.250:9090/api/v1/targets 2>/dev/null | \
  python3 -c "import sys, json; \
    targets = json.load(sys.stdin)['data']['activeTargets']; \
    flask = [t for t in targets if t['labels']['job'] == 'flask-backend']; \
    print('✓ flask-backend:', flask[0]['health'] if flask else 'NOT FOUND')" 2>/dev/null || echo "✗ Prometheus API error"
echo

echo "6. Grafana:"
curl -s -o /dev/null -w "✓ HTTP %{http_code}\n" http://192.168.122.250:3000
echo

echo "=== Health Check Complete ==="
```

Usage:
```bash
chmod +x health-check.sh
./health-check.sh
```

Expected output (healthy system):
```
=== Observability Lab Health Check ===

1. Container Status:
flask-backend   ...   Up (healthy)
frontend        ...   Up
prometheus      ...   Up
grafana         ...   Up

2. Backend Health:
✓ Healthcheck OK

3. DNS Resolution:
✓ backend → 172.18.0.7

4. API Connectivity:
✓ HTTP 200

5. Prometheus Target:
✓ flask-backend: up

6. Grafana:
✓ HTTP 200

=== Health Check Complete ===
```

---

## Additional Resources

- **Nginx Proxy Pass Options:** See `docs/phase-1-docker-compose/nginx-proxy-pass-options.md` for detailed explanation of Option 1 vs Option 2
- **Architecture Diagrams:** See main README.md for system topology
- **Grafana Dashboards:** Pre-configured in `grafana/dashboards/sli-slo-dashboard.json`
- **Prometheus Config:** Scrape targets defined in `otel-collector/prometheus.yml`
