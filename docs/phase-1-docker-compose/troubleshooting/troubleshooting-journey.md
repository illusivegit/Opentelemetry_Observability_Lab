# Troubleshooting Journey

This section documents every problem encountered, attempted solutions, and final fixes. This is the most valuable section for learning and troubleshooting similar issues.

## Issue #1: Flask Backend Container - Application Context Error

### Error Symptoms

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

### Root Cause Analysis

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

### Solution 1 (Failed): Moving Code Inside Function

**Attempt**:
```python
def initialize_app():
    SQLAlchemyInstrumentor().instrument(engine=db.engine)

if __name__ == '__main__':
    initialize_app()
    app.run(host='0.0.0.0', port=5000)
```

**Result**: Still failed because Gunicorn (production WSGI server) doesn't execute the `if __name__ == '__main__'` block.

### Solution 2 (Successful): Application Context

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

    # Now db.engine is accessible because code is in app context
    SQLAlchemyInstrumentor().instrument(engine=db.engine)

    db.create_all()
    logger.info("Database initialized")
```

**Why this works**:
- `with app.app_context():` establishes a Flask application context
- Inside this block, `db.engine` can be safely accessed
- Context is automatically cleaned up after block exits
- Code runs during module import, before any requests

### Lessons Learned

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

## Issue #2: SQLite Database - File Not Found

### Error Symptoms

```bash
$ docker logs flask-backend
sqlite3.OperationalError: unable to open database file
```

Occurred simultaneously with the application context error, but persisted after fixing that issue.

### Root Cause Analysis

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

### Solution

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

### Volume Mounting

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

### Lessons Learned

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

## Issue #3: Docker Build Cache - Code Changes Not Reflected

### Error Symptoms

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

### Root Cause Analysis

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

### Solution Attempts

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

### Prevention Strategy

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

### Lessons Learned

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

## Issue #4: Network Resolution - DNS Failure

### Error Symptoms

After successful container start:

```bash
$ docker logs flask-backend
socket.gaierror: [Errno -2] Name or service not known
urllib3.exceptions.NameResolutionError: Failed to resolve 'otel-collector'
```

Application starts, but can't send telemetry to collector.

### Root Cause Analysis

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

### Solution

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

### Network Debugging Tools

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

### Lessons Learned

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

## Issue #5: Logs Not Appearing in Loki

### Error Symptoms

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

### Root Cause Analysis

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

### Solution

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

### Logs Architecture

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

### Lessons Learned

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

## Issue #6: Loki Labels - Missing service_name

### Error Symptoms

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

### Root Cause Analysis

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

### Solution Attempt #1: Add labels Configuration (Failed)

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

### Solution Attempt #2: Check Collector Version

```bash
$ docker compose exec otel-collector /otelcontribcol --version
otelcol-contrib version 0.91.0
```

Version 0.91.0 = November 2023 = labels config removed

**Documentation search**: Found that `labels` was replaced with **attribute hints**

### Solution Attempt #3: Upgrade to v0.96.0 + Attribute Hints (Success!)

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
    "service_name"             # ← NEW - The desired label!
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

✅ **Success!** Now queries work: `{service_name="flask-backend"}`

### Label Design Considerations

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

### Lessons Learned

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
