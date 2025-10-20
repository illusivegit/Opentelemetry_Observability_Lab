# Design Decisions: Observability Lab Architecture

**Document Purpose:** Record of all major architectural decisions, trade-offs considered, and rationale for choices made during system design and implementation.

**Status:** Living Document
**Last Updated:** 2025-10-20

---

## Table of Contents

1. [Decision Framework](#decision-framework)
2. [Infrastructure Decisions](#infrastructure-decisions)
3. [Application Architecture Decisions](#application-architecture-decisions)
4. [Observability Stack Decisions](#observability-stack-decisions)
5. [CI/CD Pipeline Decisions](#cicd-pipeline-decisions)
6. [Network Architecture Decisions](#network-architecture-decisions)
7. [Security Decisions](#security-decisions)
8. [Trade-Offs and Lessons Learned](#trade-offs-and-lessons-learned)

---

## Decision Framework

All architectural decisions in this project follow this framework:

### Decision Template

```
DECISION: [Short title]
CONTEXT: [Problem being solved]
OPTIONS CONSIDERED:
  A) [Option 1]: [Pros/Cons]
  B) [Option 2]: [Pros/Cons]
  C) [Option 3]: [Pros/Cons]
CHOSEN: [Option X]
RATIONALE: [Why this option]
TRADE-OFFS ACCEPTED: [What was given up]
FUTURE RECONSIDERATION: [When to revisit]
```

---

## Infrastructure Decisions

### DD-001: Virtualization Platform (KVM vs. VirtualBox vs. Cloud VMs)

**CONTEXT:**
Need a stable, reproducible infrastructure platform for running the observability lab that simulates on-premises environments while remaining cost-effective for long-term learning.

**OPTIONS CONSIDERED:**

**Option A: KVM/QEMU/Libvirt (Chosen)**
- ✅ Pros:
  - Native Linux integration (kernel-based virtualization)
  - Production-grade hypervisor (same tech as RHEV, oVirt, Proxmox)
  - Hardware-accelerated (Intel VT-x/AMD-V)
  - Scriptable via virsh CLI
  - No licensing costs
  - Direct analogy to VMware ESXi/Hyper-V in enterprise
- ❌ Cons:
  - Steeper learning curve than VirtualBox
  - CLI-heavy (virt-manager GUI available but optional)
  - Requires host with virtualization extensions

**Option B: VirtualBox**
- ✅ Pros:
  - User-friendly GUI
  - Cross-platform (Windows, Mac, Linux)
  - Easier for beginners
- ❌ Cons:
  - Slower performance (less hardware integration)
  - Not representative of production hypervisors
  - Oracle licensing concerns
  - Less scriptable for automation

**Option C: Cloud VMs (AWS EC2, GCP Compute, Azure VMs)**
- ✅ Pros:
  - No local hardware requirements
  - Global accessibility
  - Built-in snapshots and backups
- ❌ Cons:
  - Recurring costs ($50-200/month for multi-VM setup)
  - Doesn't simulate on-prem infrastructure
  - Network complexity (VPC setup required)
  - Defeats "on-prem domain" learning goal

**CHOSEN:** Option A - KVM/QEMU/Libvirt

**RATIONALE:**
- **Enterprise Realism:** KVM is the foundation of OpenStack, oVirt, and RHEV
- **Performance:** Near-native speed with hardware virtualization
- **Cost:** Zero recurring costs (one-time hardware investment)
- **Learning Value:** Understanding libvirt XML, virsh commands, storage pools translates directly to production skills
- **Automation:** Scriptable for Ansible playbooks (future Phase 5)

**TRADE-OFFS ACCEPTED:**
- Higher initial learning curve (understanding libvirt, virt-manager)
- Requires Debian 13 host with virtualization support
- Less portable than cloud VMs (tied to physical hardware)

**FUTURE RECONSIDERATION:**
- If migrating to hybrid cloud (Phase 4), may spin up cloud VMs alongside on-prem
- If building multi-region lab, cloud VMs become necessary

---

### DD-002: VM Operating System (Debian vs. Ubuntu vs. CentOS)

**CONTEXT:**
Select OS for application VM (192.168.122.250) that balances stability, package availability, and alignment with production environments.

**OPTIONS CONSIDERED:**

**Option A: Debian 13 (Chosen)**
- ✅ Pros:
  - Rock-solid stability
  - Minimal bloat (clean base install)
  - Docker officially supports Debian
  - APT package manager (familiar)
  - Long-term support lifecycle
- ❌ Cons:
  - Packages slightly older than Ubuntu
  - Less corporate backing than RHEL/Ubuntu

**Option B: Ubuntu 22.04 LTS**
- ✅ Pros:
  - More recent packages
  - Larger community
  - Canonical commercial support available
- ❌ Cons:
  - Snaps forced in some packages (Docker conflicts)
  - More pre-installed packages (bloat)

**Option C: CentOS Stream / Rocky Linux**
- ✅ Pros:
  - RHEL-compatible (relevant for enterprise)
  - YUM/DNF package manager experience
- ❌ Cons:
  - CentOS Stream is rolling release (less stable)
  - Smaller Docker community on RHEL-based distros

**CHOSEN:** Option A - Debian 13

**RATIONALE:**
- **Stability:** Debian's conservative package approach reduces unexpected breakage
- **Docker Compatibility:** Official Docker packages work flawlessly
- **Minimalism:** Clean base image aligns with "infrastructure as code" philosophy
- **Consistency:** Host and VM run same OS family (easier troubleshooting)

**TRADE-OFFS ACCEPTED:**
- Slightly older package versions (acceptable for lab environment)
- Less commercial support than Ubuntu/RHEL (not needed for learning)

**FUTURE RECONSIDERATION:**
- If simulating RHEL enterprise environment, may add Rocky Linux VMs alongside Debian

---

## Application Architecture Decisions

### DD-003: Frontend-Backend Communication (Nginx Proxy vs. CORS Headers)

**CONTEXT:**
Browser running `http://192.168.122.250:8080` needs to make API calls to backend at `http://192.168.122.250:5000`. Browsers block cross-origin requests by default.

**OPTIONS CONSIDERED:**

**Option A: Nginx Reverse Proxy (Chosen)**
```nginx
location /api/ {
    resolver 127.0.0.11 ipv6=off valid=30s;
    set $backend_upstream http://backend:5000;
    proxy_pass $backend_upstream;
}
```
- ✅ Pros:
  - Same-origin requests (frontend and API both served from `:8080`)
  - No CORS preflight requests (performance)
  - Production-standard architecture
  - Single entry point for monitoring/logging
  - Backend not directly exposed to internet
- ❌ Cons:
  - Slightly more complex Nginx config
  - Adds routing layer (minimal latency)

**Option B: Flask CORS Headers**
```python
@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = 'http://192.168.122.250:8080'
    return response
```
- ✅ Pros:
  - Simple Python code
  - No Nginx config needed
  - Direct client-to-backend connection
- ❌ Cons:
  - Requires preflight OPTIONS requests (extra latency)
  - Must whitelist origins (fragile across environments)
  - Not how production systems are built
  - Exposes backend directly to clients

**Option C: Both Proxy and CORS (Redundant)**
- ❌ Cons:
  - Unnecessary complexity
  - CORS headers become dead code

**CHOSEN:** Option A - Nginx Reverse Proxy

**RATIONALE:**
- **Industry Standard:** This is how Netflix, Uber, Airbnb architect their systems
- **Performance:** No preflight requests, faster response times
- **Security:** Backend not directly reachable from external networks
- **Environment Agnostic:** Works on localhost, VM IP, or cloud hostname
- **Observability:** Single point to add request logging, rate limiting, etc.

**TRADE-OFFS ACCEPTED:**
- Slightly more Nginx config complexity (acceptable for learning)
- Adds reverse proxy layer (negligible latency with local Docker network)

**FUTURE RECONSIDERATION:**
- If frontend becomes SPA deployed separately (e.g., S3 + CloudFront), may need CORS
- If building public API consumed by third parties, enable CORS on specific endpoints

---

### DD-004: Database Choice (SQLite vs. PostgreSQL vs. MySQL)

**CONTEXT:**
Need persistent storage for task data. Database must support SQLAlchemy ORM and provide reasonable performance for learning environment.

**OPTIONS CONSIDERED:**

**Option A: SQLite (Chosen for PoC)**
```python
SQLALCHEMY_DATABASE_URI = 'sqlite:////app/data/tasks.db'
```
- ✅ Pros:
  - Zero configuration (no server, no authentication)
  - File-based (easy backups via volume snapshots)
  - Built into Python standard library
  - Sufficient for single-user lab workload
  - Easy to inspect with `sqlite3` CLI
- ❌ Cons:
  - No network access (can't query from outside container)
  - No concurrent write scaling
  - Limited transaction isolation
  - Not production-ready for multi-user applications

**Option B: PostgreSQL**
```python
SQLALCHEMY_DATABASE_URI = 'postgresql://user:pass@postgres:5432/tasks'
```
- ✅ Pros:
  - Production-grade RDBMS
  - Full ACID compliance
  - Concurrent writes
  - Rich SQL feature set (JSON columns, CTEs, etc.)
- ❌ Cons:
  - Requires separate container (added complexity)
  - Authentication setup
  - More resource overhead (memory, CPU)
  - Overkill for single-user lab

**Option C: MySQL**
- Similar pros/cons to PostgreSQL
- Slightly less feature-rich than PostgreSQL
- Industry usage (large web apps)

**CHOSEN:** Option A - SQLite (with migration plan to PostgreSQL in Phase 3)

**RATIONALE:**
- **Simplicity First:** For a PoC demonstrating observability, database complexity is not the focus
- **Learning Curve:** Eliminates connection pooling, authentication, and replication concerns
- **Sufficient for Goal:** Lab workload is low-volume, single-container
- **Migration Path Clear:** When moving to Kubernetes (Phase 3), swap to PostgreSQL StatefulSet

**TRADE-OFFS ACCEPTED:**
- No realistic production database experience in Phase 1
- Must use absolute file paths (`/app/data/tasks.db`) to ensure volume persistence
- No ability to query database from external tools (pgAdmin, DBeaver) without exec into container

**FUTURE RECONSIDERATION:**
- **Phase 3 (Kubernetes):** Migrate to PostgreSQL StatefulSet
- **Rationale for Migration:**
  - Multi-replica backend pods need shared database
  - Learn PostgreSQL high availability (streaming replication)
  - Practice database migration (pg_dump, schema versioning)

---

### DD-005: SQLAlchemy Instrumentation (Decorator vs. Event Listeners)

**CONTEXT:**
Need to track database query duration for P95 latency metric. SQLAlchemy provides event hooks, but initial implementation using `@event.listens_for` decorators caused "Working outside of application context" RuntimeError.

**OPTIONS CONSIDERED:**

**Option A: Event Listeners with `event.listen()` inside `app.app_context()` (Chosen)**
```python
# Define plain functions (no decorators)
def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    context._query_start_time = perf_counter()

def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    duration = perf_counter() - context._query_start_time
    prom_db_query_duration_seconds.observe(duration, {...})

# Register inside application context
with app.app_context():
    event.listen(db.engine, "before_cursor_execute", before_cursor_execute)
    event.listen(db.engine, "after_cursor_execute", after_cursor_execute)
```
- ✅ Pros:
  - Explicit registration (clear when listeners are attached)
  - Works with Flask application context lifecycle
  - Easy to unit test (functions can be called independently)
  - No magic decorators
- ❌ Cons:
  - Slightly more verbose than decorators
  - Must remember to register inside `app.app_context()`

**Option B: Decorator-Based Listeners**
```python
@event.listens_for(db.engine, "before_cursor_execute")
def before_cursor_execute(...):
    ...
```
- ✅ Pros:
  - Concise syntax
  - Automatic registration (decorator runs on import)
- ❌ Cons:
  - Caused `RuntimeError: Working outside of application context`
  - Implicit behavior (hard to debug when decorators run)
  - Doesn't work with Flask's lazy engine initialization

**Option C: SQLAlchemy-only Instrumentation (No Prometheus Metrics)**
- Rely entirely on OpenTelemetry SQLAlchemyInstrumentor
- ❌ Cons:
  - No direct Prometheus histogram for P95 latency
  - Would require Tempo spanmetrics (added complexity)

**CHOSEN:** Option A - Event Listeners with `event.listen()`

**RATIONALE:**
- **Flask Lifecycle Compatibility:** Flask doesn't create `db.engine` until inside application context
- **Explicit Registration:** Clear code flow (function definition → context activation → registration)
- **Debugging Ease:** Stack traces show exactly when listeners are registered
- **Production Pattern:** Matches how Flask extensions handle engine-dependent initialization

**TRADE-OFFS ACCEPTED:**
- Slightly more boilerplate code than decorators
- Must wrap registration in `with app.app_context():`

**LESSONS LEARNED:**
- **Flask Application Context is Critical:** Anything touching `db.engine` must be inside context
- **Decorators Run at Import Time:** Decorators execute when Python imports the module, before Flask app is initialized
- **Explicit is Better Than Implicit:** PEP 20 (Zen of Python) applies to framework initialization

---

## Observability Stack Decisions

### DD-006: Metric Instrumentation (Prometheus Client vs. OTel SDK Metrics)

**CONTEXT:**
After initial implementation, discovered **metric duplication**: the same metric (`http_requests_total`) appeared twice in Prometheus with different `job` labels. Root cause: Both Prometheus client *and* OTel SDK metrics were active.

**OPTIONS CONSIDERED:**

**Option A: Prometheus Client Only (Chosen)**
```python
from prometheus_client import Counter, Histogram
prom_http_requests_total = Counter('http_requests_total', ...)
prom_http_request_duration_seconds = Histogram('http_request_duration_seconds', ...)
# Exposed at /metrics endpoint, Prometheus scrapes directly
```
- ✅ Pros:
  - Single source of truth (no duplication)
  - Purpose-built for Prometheus (optimal metric format)
  - Dashboards work immediately (no `job` label filtering needed)
  - Simpler mental model (metrics != telemetry pipeline)
  - SLI metrics don't need OTel enrichment (counters/histograms are simple)
- ❌ Cons:
  - Lose OTel metrics pipeline features (processor enrichment)
  - Can't send metrics through collector for centralized processing

**Option B: OTel SDK Metrics Only**
```python
from opentelemetry import metrics
meter = metrics.get_meter(__name__)
http_requests_total = meter.create_counter('http_requests_total', ...)
# Export via OTLP → Collector → Prometheus
```
- ✅ Pros:
  - Unified telemetry pipeline (traces, metrics, logs all through collector)
  - Can apply OTel processors (batching, resource attributes)
- ❌ Cons:
  - OTel metrics spec is less mature than traces/logs
  - Must configure Prometheus exporter in collector (added complexity)
  - Dashboard queries need to filter by `job="otel-collector-prometheus-exporter"`
  - Duplicates Prometheus client metrics if both are active

**Option C: Both, with Renamed Metrics**
```python
# Prometheus client
prom_http_requests_total = Counter('app_http_requests_total', ...)
# OTel SDK
http_requests_total = meter.create_counter('otel_http_requests_total', ...)
```
- ✅ Pros:
  - No collision (different metric names)
  - Can compare Prometheus vs. OTel metrics
- ❌ Cons:
  - Wastes storage (duplicate time series)
  - Confusing for dashboard creators (which metric to use?)
  - Must update all dashboard queries

**CHOSEN:** Option A - Prometheus Client Only

**RATIONALE:**
- **Simplicity:** Single metric source eliminates confusion and duplication
- **OTel Value Preserved:** Traces (the real power of OTel) still flow through collector
- **Logs Still Centralized:** Logs go through OTLP → Collector → Loki (correlation intact)
- **SLI Metrics are Simple:** Request counts and latency histograms don't need OTel's distributed context
- **Immediate Dashboard Compatibility:** Existing PromQL queries work without modification

**TRADE-OFFS ACCEPTED:**
- **Lost OTel Metric Features:**
  - Can't apply resource processor to add environment labels (must add in Prometheus client)
  - Can't batch metrics before export (Prometheus scrapes directly)
  - Can't send metrics to multiple backends via collector fan-out
- **Acceptable Because:**
  - Metrics are scraped every 15 seconds (batching less critical)
  - Environment labels can be added via Prometheus relabeling
  - Only need one metrics backend (Prometheus) for this lab

**FUTURE RECONSIDERATION:**
- **When to Revisit:**
  - If implementing multi-tenant observability (need central metric gateway)
  - If adding Thanos for long-term metric storage (might want collector aggregation)
  - If OTel metrics spec matures significantly (better Prometheus compatibility)

**LESSONS LEARNED:**
1. **Not All Telemetry Needs OTel:**
   - **Traces:** OTel is essential (distributed context propagation)
   - **Logs:** OTel valuable (structured export, trace correlation)
   - **Metrics:** Prometheus client is often simpler for app-level SLIs

2. **Check for Duplication Early:**
   - Query Prometheus: `count by (__name__, job) (http_requests_total)`
   - If count > 1, you have duplicate sources

3. **Understand Collector Exporters:**
   - `prometheus` exporter exposes port for *Prometheus to scrape*
   - `prometheusremotewrite` exporter *pushes* to Prometheus remote write endpoint
   - Using both with OTel SDK metrics creates double-write scenario

---

### DD-007: Nginx DNS Resolution (Static vs. Dynamic)

**CONTEXT:**
Nginx 502 "Bad Gateway" errors occurred when backend container restarted. Nginx cached the initial IP of `backend` service and didn't re-resolve after restart. New backend container had different IP, but Nginx kept trying old IP.

**OPTIONS CONSIDERED:**

**Option A: Dynamic DNS with Resolver Directive (Chosen)**
```nginx
location /api/ {
    resolver 127.0.0.11 ipv6=off valid=30s;  # Docker DNS
    set $backend_upstream http://backend:5000;
    proxy_pass $backend_upstream;  # Variable-based (re-resolves)
}
```
- ✅ Pros:
  - Nginx re-resolves DNS on every request
  - Handles backend container restarts gracefully
  - Production-ready pattern (used by Kubernetes Ingress)
  - TTL controls cache duration (30s balance)
- ❌ Cons:
  - Slightly more complex config (resolver directive + variable)
  - Minimal DNS lookup overhead per request (acceptable on local network)

**Option B: Static Hostname Resolution**
```nginx
location /api/ {
    proxy_pass http://backend:5000/api/;  # Resolved once at startup
}
```
- ✅ Pros:
  - Simpler configuration
  - No per-request DNS overhead
- ❌ Cons:
  - **Breaks on container restart** (cached stale IP)
  - Requires Nginx reload after backend changes
  - Not production-suitable (doesn't handle dynamic environments)

**Option C: Frontend Depends on Backend (Startup Order)**
```yaml
frontend:
  depends_on:
    backend:
      condition: service_healthy
```
- ✅ Pros:
  - Ensures backend is running when frontend starts
  - Eliminates "backend not found" errors at startup
- ❌ Cons:
  - **Doesn't solve restart problem:** If backend restarts *after* frontend is running, Nginx still has stale IP
  - Only solves initial startup race condition

**CHOSEN:** Option A + Option C (Layered Defense)

**RATIONALE:**
- **Option C Solves Startup:** Frontend waits for backend healthcheck before starting
- **Option A Solves Runtime:** Nginx re-resolves DNS after backend restarts
- **Together:** Eliminate both startup race conditions and runtime IP staleness

**TRADE-OFFS ACCEPTED:**
- Slightly more complex Nginx config (acceptable for reliability)
- Minimal DNS lookup overhead (127.0.0.11 is local Docker DNS, <1ms)

**IMPLEMENTATION DETAILS:**

**Why `resolver 127.0.0.11`?**
- Docker's embedded DNS server listens on 127.0.0.11 inside every container
- Resolves service names (e.g., `backend`) to current container IPs
- Updated dynamically when containers start/stop

**Why `set $backend_upstream`?**
- Nginx optimizes: `proxy_pass http://backend:5000;` resolves once at startup
- Variable forces Nginx to re-evaluate: `set $var http://backend:5000; proxy_pass $var;`
- Each request triggers DNS lookup (with TTL caching)

**Why `valid=30s`?**
- Balance between:
  - Too short (1s): Excessive DNS queries
  - Too long (5m): Slow to detect backend IP changes
- 30s: Backend restart detected within 30 seconds (acceptable for lab)

**FUTURE RECONSIDERATION:**
- In Kubernetes: Ingress controllers handle this automatically (service discovery via API)
- In production: Consider health checks + exponential backoff for DNS failures

**LESSONS LEARNED:**
1. **Docker DNS is Dynamic:** Container IPs change on restart (Docker assigns from pool)
2. **Nginx Caches Aggressively:** Default behavior optimizes for static servers
3. **Variables Disable Caching:** Nginx treats variables as dynamic (re-evaluated per request)
4. **Layered Defense:** Combine startup ordering + runtime DNS updates for full resilience

---

### DD-008: Backend Healthcheck (HTTP vs. TCP vs. Python Script)

**CONTEXT:**
`depends_on: service_healthy` requires a healthcheck to determine when backend is ready. Initial HTTP-based healthcheck using `curl` failed because `curl` not installed in `python:3.11-slim` image.

**OPTIONS CONSIDERED:**

**Option A: Python-Based HTTP Healthcheck (Chosen)**
```yaml
healthcheck:
  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/metrics', timeout=2)"]
  interval: 5s
  timeout: 2s
  retries: 3
  start_period: 5s
```
- ✅ Pros:
  - Uses Python stdlib (no external dependencies)
  - Tests actual application (not just port binding)
  - Validates `/metrics` endpoint is serving content
  - urllib.request available in all Python versions
- ❌ Cons:
  - Slightly verbose (one-liner Python script)
  - Must ensure Flask is fully initialized

**Option B: curl-Based HTTP Healthcheck**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
```
- ✅ Pros:
  - Standard syntax (widely used)
  - Concise command
- ❌ Cons:
  - **Requires installing curl:** Adds 5MB to image, slows build
  - python:3.11-slim doesn't include curl
  - Unnecessary dependency

**Option C: TCP Port Check**
```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z localhost 5000"]
```
- ✅ Pros:
  - Lightweight (just checks port is listening)
  - Fast execution
- ❌ Cons:
  - **Doesn't test application:** Port open != app ready
  - Flask could be crashed but port still bound
  - Requires netcat (not in slim image)

**Option D: No Healthcheck (Rely on Startup Time)**
```yaml
depends_on:
  backend:
    condition: service_started  # No healthcheck
```
- ✅ Pros:
  - Simplest config
- ❌ Cons:
  - **Race condition:** Frontend might start before backend is ready to serve requests
  - Nginx DNS lookup could fail if backend not fully initialized

**CHOSEN:** Option A - Python-Based HTTP Healthcheck

**RATIONALE:**
- **No External Dependencies:** Python stdlib is already in the image
- **Tests Real Readiness:** Validates Flask app is serving HTTP responses
- **Accurate Health Signal:** Frontend won't start until backend is *actually* ready
- **Slim Image Friendly:** No need to install curl, wget, or netcat

**TRADE-OFFS ACCEPTED:**
- Healthcheck command is longer (one-liner Python script)
- Must ensure `/metrics` endpoint is initialized (always true in this app)

**IMPLEMENTATION NOTES:**

**Why Test `/metrics` Instead of `/health`?**
- `/metrics` endpoint exists for Prometheus scraping (always present)
- If `/metrics` works, Flask is definitely initialized
- Eliminates need to create dedicated `/health` endpoint

**Healthcheck Parameters Explained:**
- `interval: 5s` - Check every 5 seconds
- `timeout: 2s` - Fail if request takes >2 seconds
- `retries: 3` - Mark unhealthy after 3 consecutive failures
- `start_period: 5s` - Grace period on container start (failures don't count)

**Alternative Python Healthcheck (More Robust):**
```python
import sys, urllib.request
try:
    resp = urllib.request.urlopen('http://localhost:5000/metrics', timeout=2)
    sys.exit(0 if resp.status == 200 else 1)
except Exception:
    sys.exit(1)
```
- Tests HTTP 200 status explicitly
- Handles exceptions gracefully
- Current one-liner is sufficient (urllib.request raises exception on non-200)

**FUTURE RECONSIDERATION:**
- In Kubernetes: Replace with HTTP liveness/readiness probes (native K8s feature)
```yaml
livenessProbe:
  httpGet:
    path: /metrics
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 10
```

**LESSONS LEARNED:**
1. **Slim Images Are Minimal:** Don't assume curl/wget/nc are present
2. **Use What You Have:** Python stdlib is powerful (urllib, socket, http.server)
3. **Test Real Behavior:** Port checks don't guarantee app is ready
4. **Healthchecks Are Critical:** Prevent race conditions in orchestrated environments

---

## CI/CD Pipeline Decisions

### DD-009: Pipeline Deployment Method (Docker Context vs. SSH vs. Ansible)

**CONTEXT:**
Jenkins pipeline needs to deploy Docker Compose stack to remote VM (192.168.122.250). Must handle file synchronization (bind mounts require files on VM filesystem).

**OPTIONS CONSIDERED:**

**Option A: SSH + rsync (Chosen)**
```groovy
stage('Sync repo to VM') {
  sshagent(credentials: ['vm-ssh']) {
    sh '''
      ssh ${VM_USER}@${VM_IP} "mkdir -p ${VM_DIR}"
      rsync -az --delete ./ ${VM_USER}@${VM_IP}:${VM_DIR}/
    '''
  }
}
stage('Compose up (remote via SSH)') {
  sshagent(credentials: ['vm-ssh']) {
    sh '''
      ssh ${VM_USER}@${VM_IP} "
        cd ${VM_DIR} && PROJECT=${PROJECT} LAB_HOST=${VM_IP} ./start-lab.sh
      "
    '''
  }
}
```
- ✅ Pros:
  - Works with standard SSH hardening (no Docker daemon exposure)
  - rsync efficiently syncs only changed files
  - Clear separation: sync → deploy
  - Doesn't require Docker daemon listening on network
- ❌ Cons:
  - Requires SSH keys configured in Jenkins credentials
  - Two-step process (sync files, then deploy)
  - Must manage remote file paths

**Option B: Docker Context (TLS/SSH)**
```groovy
stage('Setup Docker Context') {
  sh '''
    docker context create vm-lab \
      --docker "host=ssh://${VM_USER}@${VM_IP}"
  '''
}
stage('Deploy to Remote Context') {
  sh '''
    docker --context vm-lab compose -p lab up -d --build
  '''
}
```
- ✅ Pros:
  - Native Docker CLI (no custom SSH commands)
  - Single-step deployment
  - Can use docker-compose from Jenkins agent
- ❌ Cons:
  - **Bind mounts break:** Docker context doesn't sync files to remote host
  - Example: `./frontend/default.conf:/etc/nginx/conf.d/default.conf`
    - File exists on Jenkins agent
    - Doesn't exist on VM
    - Container fails to start
  - Would require all files to be on VM beforehand (defeats purpose)

**Option C: Ansible Playbook**
```yaml
# deploy.yml
- hosts: application_vm
  tasks:
    - name: Sync files
      synchronize:
        src: ./
        dest: /home/deploy/lab/app
    - name: Deploy stack
      community.docker.docker_compose:
        project_src: /home/deploy/lab/app
        state: present
```
- ✅ Pros:
  - Declarative (idempotent)
  - Built-in modules for sync + docker-compose
  - Scalable (can deploy to multiple VMs)
- ❌ Cons:
  - Adds Ansible dependency to Jenkins agent
  - Overkill for single VM deployment
  - Learning curve for Ansible syntax

**CHOSEN:** Option A - SSH + rsync (with future migration to Ansible in Phase 5)

**RATIONALE:**
- **Works Today:** SSH is already configured, rsync is available on Jenkins agent
- **Secure:** Doesn't require exposing Docker daemon on network (2375/2376)
- **Bind Mount Compatible:** Files are synced to VM before `docker compose` runs
- **Debuggable:** Can manually SSH to VM and inspect state

**TRADE-OFFS ACCEPTED:**
- Manual SSH key management (Jenkins credentials plugin)
- Two-stage deployment (sync, then compose)
- Hardcoded VM path (`/home/deploy/lab/app`)

**IMPLEMENTATION DETAILS:**

**rsync Flags:**
- `-a` (archive): Preserves permissions, timestamps, symlinks
- `-z` (compress): Reduces network transfer (minimal on LAN)
- `--delete`: Removes files on VM that don't exist in source (clean state)

**Why `sshagent`?**
- Jenkins plugin that injects SSH private key into agent environment
- Allows `ssh` and `rsync` commands to authenticate without password
- Credentials stored in Jenkins (encrypted at rest)

**Alternative: Docker Context with Pre-Sync**
```groovy
// Hybrid approach (not used, but viable)
stage('Sync files') {
  sh 'rsync -az ./ ${VM_USER}@${VM_IP}:${VM_DIR}/'
}
stage('Deploy via context') {
  sh '''
    docker context create vm-lab --docker "host=ssh://..."
    docker --context vm-lab compose --project-directory ${VM_DIR} up -d
  '''
}
```
- Could work, but mixing rsync + Docker context adds complexity
- Current approach (all via SSH) is clearer

**FUTURE RECONSIDERATION:**

**Phase 5: Ansible Migration**
- Create `playbooks/deploy-observability.yml`
- Use `ansible-playbook` in Jenkins pipeline
- Benefits:
  - Idempotent (can run repeatedly without side effects)
  - Variable templating (dev/staging/prod environments)
  - Role-based organization (sync, deploy, test as separate roles)
  - Scalable to multi-VM deployments

**LESSONS LEARNED:**
1. **Docker Context Limitations:** Remote contexts don't sync files (assumes files already on host)
2. **Bind Mounts Require Local Files:** Containers need files on the Docker daemon's filesystem
3. **SSH + rsync is Reliable:** Simple, secure, works with existing infrastructure
4. **Start Simple, Refactor Later:** Ansible is future goal, but SSH works today

---

### DD-009b: Single Source of Truth for Project Name (Hardcoded vs. Environment Variable)

**CONTEXT:**
The startup script (`start-lab.sh`) and Jenkinsfile both use `PROJECT="lab"` for Docker Compose project naming. Initially, these were hardcoded in both files, creating a maintenance problem: if the project name changed, both files would need manual updates. Additionally, the startup script needed to work both locally (for developers) and remotely (when invoked by Jenkins pipeline), making environment-agnostic design critical.

**THE PROBLEM:**
```bash
# start-lab.sh
PROJECT="lab"  # ← Hardcoded

# Jenkinsfile
environment {
  PROJECT = 'lab'  # ← Hardcoded in different file
}
```

If these values diverge, container names won't match between local and pipeline deployments, causing confusion and errors.

**OPTIONS CONSIDERED:**

**Option A: Script Accepts Environment Variable with Default (Chosen)**
```bash
# start-lab.sh
PROJECT="${PROJECT:-lab}"      # Use env var if set, default to "lab"
LAB_HOST="${LAB_HOST:-localhost}"
```

**Jenkins invocation:**
```groovy
ssh ${VM_USER}@${VM_IP} "
  cd ${VM_DIR} && \
  PROJECT=${PROJECT} LAB_HOST=${VM_IP} ./start-lab.sh
"
```

- ✅ Pros:
  - Single source of truth: Jenkinsfile defines PROJECT, script uses it
  - Works locally without changes (`./start-lab.sh` uses default "lab")
  - Works in pipeline (Jenkins passes PROJECT as env var)
  - No extra files to maintain
  - Follows Unix philosophy (accept input from environment, provide sensible defaults)
  - Script is truly environment-agnostic
- ❌ Cons:
  - Slightly less obvious than hardcoded value (but well-documented)

**Option B: Shared Configuration File**
```bash
# config.sh
PROJECT=lab
DOCKER_BUILDKIT=1
```

Both files source it:
```bash
source ./config.sh
```

- ✅ Pros:
  - Explicit single source of truth file
  - Easy to locate all configuration
- ❌ Cons:
  - Extra file to maintain
  - Must ensure it's committed to Git
  - Both Jenkinsfile and script need to source it
  - Doesn't work if file isn't synced to remote VM first

**Option C: Keep Separate (Document Sync Requirement)**
```markdown
⚠️ **Important:** Ensure PROJECT matches in both files:
- start-lab.sh: PROJECT="lab"
- Jenkinsfile: PROJECT = 'lab'
```

- ✅ Pros:
  - No code changes needed
  - Simple for users who only use one method
- ❌ Cons:
  - Manual synchronization required
  - Easy to forget and cause deployment mismatch
  - Not DRY (Don't Repeat Yourself)
  - Violates single source of truth principle

**CHOSEN:** Option A - Environment Variable with Default

**RATIONALE:**
- **Simplicity:** One-line change (`PROJECT="${PROJECT:-lab}"`) solves the entire problem
- **Unix Philosophy:** Accept configuration from environment, provide sensible defaults
- **Local Development:** Developers run `./start-lab.sh` and it "just works"
- **Pipeline Integration:** Jenkins passes `PROJECT=${PROJECT}` and script uses pipeline's value
- **Zero Maintenance Overhead:** No extra files, no synchronization requirements
- **Future-Proof:** If PROJECT name changes, update only Jenkinsfile environment section

**IMPLEMENTATION:**

**Before (Hardcoded):**
```bash
#!/bin/bash
PROJECT="lab"  # ← Hardcoded, duplicated in Jenkinsfile
docker compose -p ${PROJECT} up -d --build
```

**After (Environment-Aware):**
```bash
#!/bin/bash
PROJECT="${PROJECT:-lab}"      # ← Use env var if set, default to "lab"
LAB_HOST="${LAB_HOST:-localhost}"
echo "📦 Using project name: ${PROJECT}"
echo "🌐 Using access host: ${LAB_HOST}"
docker compose -p ${PROJECT} up -d --build
```

**How It Works:**
- `${PROJECT:-lab}` / `${LAB_HOST:-localhost}` use Bash parameter expansion:
  - If the environment variable exists and is non-empty: use it
  - Otherwise: use the documented default (`"lab"` or `"localhost"`)

**Usage Examples:**

**Local Development (no env var):**
```bash
./start-lab.sh
# Output: 📦 Using project name: lab
#         🌐 Using access host: localhost
# Internally runs: docker compose -p lab up -d --build
```

**Jenkins Pipeline (env var passed):**
```groovy
environment {
  PROJECT = 'lab'
  VM_IP   = '192.168.122.250'
}
stage('Deploy') {
  sh '''
    ssh ${VM_USER}@${VM_IP} "
      cd ${VM_DIR} && \
      PROJECT=${PROJECT} LAB_HOST=${VM_IP} ./start-lab.sh
    "
  '''
}
# Script receives PROJECT=lab from Jenkins
# Output: 📦 Using project name: lab
#         🌐 Using access host: 192.168.122.250
# Internally runs: docker compose -p lab up -d --build
```

**Custom Local Override (testing):**
```bash
PROJECT=test-env ./start-lab.sh
# Output: 📦 Using project name: test-env
#         🌐 Using access host: localhost
# Runs: docker compose -p test-env up -d --build
```

**TRADE-OFFS ACCEPTED:**
- Environment variable behavior may be less obvious to beginners than hardcoded value
- **Mitigation:** Script echoes the project name being used, and README documents behavior

**BENEFITS REALIZED:**
1. **DRY Principle:** PROJECT defined once in Jenkinsfile, used everywhere
2. **Environment Agnostic:** Same script works locally, in pipeline, in different environments
3. **No Configuration Drift:** Impossible for values to get out of sync
4. **Developer Experience:** Local users don't need to know about Jenkins pipeline
5. **Pipeline Consistency:** Jenkins controls deployment parameters across all environments

**DESIGN PRINCIPLE DEMONSTRATED:**

This decision exemplifies **pragmatic simplicity over premature optimization**:
- **Problem identified:** Hardcoded values in two places create maintenance burden
- **Simple solution exists:** Bash parameter expansion with default
- **Implementation cost:** One line of code
- **Maintenance benefit:** Eliminates entire class of sync errors

**This is how production systems should be designed:** Find the simplest solution that eliminates the problem entirely, not the most clever solution.

**FUTURE RECONSIDERATION:**
- If configuration becomes complex (10+ variables), revisit shared config file approach
- For now, single variable + environment default is optimal

**LESSON LEARNED:**
When facing configuration duplication, ask: "Can I accept this from the environment with a sensible default?" This pattern works for:
- Project names
- Environment names (dev/staging/prod)
- Feature flags
- API endpoints
- Any value that might differ between local and deployed environments

---

## Network Architecture Decisions

### DD-010: Docker Network Mode (Bridge vs. Host vs. Overlay)

**CONTEXT:**
Containers need to communicate internally (backend → otel-collector) while also exposing ports to VM host (for external access).

**OPTIONS CONSIDERED:**

**Option A: Bridge Network (Chosen)**
```yaml
networks:
  otel-network:
    driver: bridge
services:
  backend:
    networks:
      - otel-network
  frontend:
    networks:
      - otel-network
    ports:
      - "8080:80"
```
- ✅ Pros:
  - Container isolation (separate network namespace)
  - DNS-based service discovery (backend → otel-collector via hostname)
  - Explicit port mapping (only exposed ports reachable from host)
  - Standard Docker networking (most common pattern)
- ❌ Cons:
  - Slight network overhead (iptables NAT)
  - Container IPs are internal (172.18.0.x range)

**Option B: Host Network**
```yaml
services:
  backend:
    network_mode: host
```
- ✅ Pros:
  - No network overhead (container uses host's network stack)
  - Faster performance (no NAT)
- ❌ Cons:
  - **Port conflicts:** All containers on same network (can't have two services on port 5000)
  - No isolation (containers can access all host ports)
  - No DNS service discovery (must use localhost:port)

**Option C: Overlay Network (Multi-Host)**
```yaml
networks:
  otel-network:
    driver: overlay
```
- ✅ Pros:
  - Multi-host communication (for Docker Swarm or multi-VM deployments)
- ❌ Cons:
  - Requires Docker Swarm mode
  - Overkill for single-host lab
  - More complex setup

**CHOSEN:** Option A - Bridge Network

**RATIONALE:**
- **Service Discovery:** Containers resolve each other by service name (e.g., `backend`, `prometheus`)
- **Isolation:** Each service has dedicated internal IP, port conflicts impossible
- **Port Control:** Explicitly map only necessary ports to host (8080, 3000, 9090, etc.)
- **Standard Pattern:** Matches how Kubernetes networking works (pod-to-pod via service names)

**TRADE-OFFS ACCEPTED:**
- Minimal performance overhead from bridge NAT (negligible on local host)
- Container IPs are ephemeral (change on restart) - solved by DNS resolution

**FUTURE RECONSIDERATION:**
- **Phase 3 (Kubernetes):** Bridge networks become Kubernetes Services (ClusterIP)
- **Multi-VM Lab:** May use overlay network to connect containers across VMs

**LESSONS LEARNED:**
1. **DNS is Key:** Bridge networks provide automatic DNS (service name → IP)
2. **Isolation Prevents Conflicts:** Each container has its own network namespace
3. **Port Mapping is Explicit:** `ports: ["8080:80"]` makes external access clear

---

## Security Decisions

### DD-011: SSH Authentication Method (Key-Only vs. Password vs. Both)

**CONTEXT:**
Jenkins pipeline needs SSH access to target VM (192.168.122.250) for deployment. Must balance security (prevent brute-force attacks) with usability (pipeline automation).

**OPTIONS CONSIDERED:**

**Option A: Key-Only Authentication (Chosen)**
```bash
# SSH daemon config
PubkeyAuthentication yes
PasswordAuthentication no

# Lock user password
sudo passwd -l deploy
```
- ✅ Pros:
  - Industry best practice for production servers
  - Eliminates brute-force password attack vector
  - Required for automated pipelines (no interactive password prompts)
  - Audit trail (each key is identifiable by comment/fingerprint)
  - Revocable (remove key from authorized_keys, user still exists)
- ❌ Cons:
  - More complex initial setup (key generation, distribution)
  - Key management overhead (rotation, backup)
  - If private key compromised, attacker has access (until key removed)

**Option B: Password Authentication**
```bash
# SSH daemon config
PasswordAuthentication yes
```
- ✅ Pros:
  - Simple setup (just set password)
  - No key management
  - User can log in from any machine
- ❌ Cons:
  - **Vulnerable to brute-force attacks** (exposed to internet = minutes until attack)
  - Can't automate (Jenkins can't enter password interactively)
  - Weak passwords are common (humans are predictable)
  - No audit trail (can't distinguish legitimate vs. compromised login)

**Option C: Both Keys and Passwords**
```bash
PubkeyAuthentication yes
PasswordAuthentication yes
```
- ✅ Pros:
  - Flexibility (keys for automation, password for emergency access)
- ❌ Cons:
  - **Weakest link problem:** Password auth enabled = brute-force risk remains
  - False sense of security ("I have keys, so I'm safe" while password auth is on)
  - Best practice: disable unused auth methods

**CHOSEN:** Option A - Key-Only Authentication

**RATIONALE:**
- **Security First:** Even in lab environment, practice production-grade security
- **Automation Requirement:** Jenkins pipeline needs non-interactive SSH
- **Learning Opportunity:** Proper key management is fundamental DevSecOps skill
- **Defense in Depth:** Combine with fail2ban, firewall rules (future Phase 2)

**IMPLEMENTATION DETAILS:**

**Key Generation (ED25519 vs. RSA):**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_jenkins -C "jenkins-deployment-key"
```
- Chose ED25519 over RSA-4096:
  - Smaller key size (256 bits vs. 4096 bits)
  - Faster cryptographic operations
  - Equivalent or better security (EdDSA vs. RSA)
  - Modern standard (OpenSSH 6.5+, 2014)

**Key Distribution Process:**
1. Generate key pair on Jenkins host
2. Set temporary password on `deploy` user
3. Use `ssh-copy-id` to install public key
4. Test key-based login
5. Lock password: `sudo passwd -l deploy`
6. Disable password auth in `sshd_config`
7. Restart SSH daemon
8. Final test (ensure password fails, key works)

**Why Walk Through Full Process (Not Just Copy-Paste Key)?**
- **Training Value:** Each step reinforces understanding of SSH security
- **Muscle Memory:** Next server provisioning will be automatic
- **Production Mindset:** Shortcuts in lab = mistakes in production

**SSH Daemon Hardening:**
```bash
# /etc/ssh/sshd_config
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no  # Never allow root login
X11Forwarding no     # Disable unless needed
MaxAuthTries 3       # Limit authentication attempts
```

**TRADE-OFFS ACCEPTED:**
- Must securely store private key (Jenkins credentials plugin, Vault)
- Key rotation requires manual process (copy new key, remove old)
- Lost private key = must use VM console to add new key (or rebuild VM)

**FUTURE ENHANCEMENTS (Phase 2):**

**Planned Security Hardening:**
- Implement fail2ban (block repeated failed auth attempts)
- Configure UFW firewall (allow only necessary ports)
- Two-factor authentication for SSH (Google Authenticator PAM module)
- Key rotation policy (rotate keys every 90 days)
- Audit logging (rsyslog + centralized SIEM)

**Resource Bookmarked:**
[How To Secure A Linux Server](https://github.com/imthenachoman/How-To-Secure-A-Linux-Server)
- Comprehensive hardening guide covering:
  - fail2ban configuration
  - iptables/UFW firewall rules
  - Kernel parameter hardening (`sysctl.conf`)
  - AppArmor/SELinux profiles
  - File system security (noexec on /tmp, etc.)
  - Intrusion detection (AIDE, Tripwire)
  - Audit logging (auditd)
- Will implement incrementally as project matures

**LESSONS LEARNED:**
1. **Security is Iterative:** Start with SSH keys, add fail2ban, then HIDS, then...
2. **Practice in Lab:** Build security habits in safe environment
3. **Automation Requires Security:** Can't automate with password prompts
4. **Documentation is Security:** Record what was hardened and why

**FUTURE RECONSIDERATION:**
- **If Adding Bastion Host:** May need certificate-based SSH (signed keys)
- **If Multiple Maintainers:** Consider separate keys per user
- **If Compliance Required:** Implement key rotation automation (Ansible playbook)

---

### DD-012: Secrets Management (Vault vs. Environment Variables vs. Hardcoded)

**CONTEXT:**
Application may need secrets (database passwords, API keys) in future iterations. Current SQLite setup has no passwords, but planning ahead.

**OPTIONS CONSIDERED:**

**Option A: HashiCorp Vault (Chosen for Jenkins Infra, Future for App)**
- Currently: Used in Jenkins environment for SSH keys
- Future: Backend can fetch DB credentials from Vault API
- ✅ Pros:
  - Centralized secrets management
  - Audit logging (who accessed what secret when)
  - Secret rotation support
  - Industry standard
- ❌ Cons:
  - Added complexity (Vault server required)
  - Initial setup (unsealing, policies)

**Option B: Docker Secrets (Swarm-Only)**
```yaml
services:
  backend:
    secrets:
      - db_password
secrets:
  db_password:
    external: true
```
- ✅ Pros:
  - Native Docker integration
  - Secrets mounted as files (/run/secrets/db_password)
- ❌ Cons:
  - **Requires Docker Swarm mode** (not using Swarm)
  - Doesn't work with `docker compose` (only `docker stack deploy`)

**Option C: Environment Variables**
```yaml
services:
  backend:
    environment:
      - DB_PASSWORD=mysecretpassword
```
- ✅ Pros:
  - Simple (no external dependencies)
  - Works with any orchestrator
- ❌ Cons:
  - **Visible in `docker inspect`** (not encrypted)
  - Logged in container startup (security risk)
  - No rotation mechanism

**Option D: Hardcoded in Code**
```python
DB_PASSWORD = "hardcoded_secret"
```
- ❌ Cons:
  - Terrible practice (committed to Git)
  - Exposed in logs, stack traces
  - No excuse to do this

**CHOSEN:** Option A - Vault (with fallback to environment variables for non-sensitive config)

**RATIONALE:**
- **Future-Proof:** When migrating to PostgreSQL (Phase 3), Vault is ready
- **Learning Value:** Vault integration is valuable DevSecOps skill
- **Jenkins Already Has It:** Reuse existing Vault server in Jenkins network
- **Non-Secrets via Env Vars:** Non-sensitive config (e.g., `FLASK_ENV=production`) can use env vars

**CURRENT STATE:**
- SQLite has no password (file-based database)
- No secrets currently needed
- Vault server running in Jenkins network (not yet integrated with app)

**FUTURE IMPLEMENTATION (Phase 2):**
```python
# backend/app.py
import hvac  # HashiCorp Vault Python client

vault_client = hvac.Client(url='http://vault-server:8200')
vault_client.token = os.environ['VAULT_TOKEN']  # Injected by Jenkins
secret = vault_client.secrets.kv.v2.read_secret_version(path='database/postgres')
DB_PASSWORD = secret['data']['data']['password']
```

**LESSONS LEARNED:**
1. **Plan for Secrets Early:** Easier to add Vault integration from start than retrofit later
2. **Separate Sensitive and Non-Sensitive:** Not all config needs Vault (e.g., port numbers, hostnames)
3. **Vault is Standard:** Used by Netflix, Uber, Adobe - worth learning

---

## Trade-Offs and Lessons Learned

### Summary of Accepted Trade-Offs

| Decision | What Was Given Up | What Was Gained | Worth It? |
|----------|----------------|----------------|-----------|
| **SQLite vs. PostgreSQL** | Production database features | Simplicity, zero config | ✅ Yes (for PoC), will migrate in Phase 3 |
| **Prometheus Client (No OTel Metrics)** | Centralized metric processing | Single source, no duplication | ✅ Yes, traces are the real OTel value |
| **Nginx Proxy vs. CORS** | Direct client→backend connection | Same-origin, production pattern | ✅ Yes, industry standard |
| **SSH Deployment vs. Ansible** | Declarative infrastructure as code | Works today, no learning curve | ✅ Yes, Ansible is Phase 5 goal |
| **KVM vs. Cloud VMs** | Cloud portability, pay-as-you-go | Zero recurring costs, on-prem simulation | ✅ Yes, aligns with "on-prem domain" vision |
| **Dynamic DNS in Nginx** | Slight performance overhead | Resilience to backend restarts | ✅ Yes, prevents 502 errors |
| **Key-Only SSH (vs. Password)** | Convenience of password login | Eliminates brute-force attacks, enables automation | ✅ Yes, production-grade security |
| **Environment Variable for PROJECT** | Slightly less obvious than hardcoded | Single source of truth, environment-agnostic script | ✅ Yes, eliminates config drift with one line |

---

### Key Lessons Learned

**1. Start Simple, Refactor Based on Needs**
- SQLite → PostgreSQL migration is planned, not premature
- SSH deployment works today, Ansible is future enhancement
- Don't over-engineer before understanding requirements

**2. Observability Should Be Invisible**
- Automatic instrumentation (FlaskInstrumentor, SQLAlchemyInstrumentor) requires zero code changes to business logic
- Traces, metrics, logs flow without developers thinking about them
- **Anti-Pattern:** Making developers manually create spans everywhere

**3. Documentation is a First-Class Deliverable**
- This design decisions document captures *why*, not just *what*
- Future me (and others) will thank present me for recording rationale
- Architecture diagrams + decision records = complete picture

**4. Security is Easier to Add Early**
- Vault integration planned from start (even if not used yet)
- SSH key-based authentication (never passwords)
- Pre-commit hooks (Phase 2) catch secrets before they hit Git

**5. Infrastructure as Code (Implicit)**
- All config in Git (docker-compose.yml, Nginx conf, Grafana dashboards)
- Deployment is `git clone` + `docker compose up`
- No manual "click here, configure that" steps

**6. Fail Fast and Learn**
- Every error (RuntimeError, 502, database not found) taught something
- Documented each failure in IMPLEMENTATION-GUIDE.md
- Trial and error is the fastest path to understanding

---

**Document Version:** 1.0
**Author:** Wally
**Last Updated:** 2025-10-20
**Status:** Living Document (will be updated as new decisions are made)

**License:** MIT (use for your own learning)
