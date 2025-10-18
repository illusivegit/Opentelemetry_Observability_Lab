# Building a Production-Grade Observability Lab: A Journey of Trial, Error, and Victory

*A DevSecOps tale of falling forward through OpenTelemetry, distributed tracing, and countless Docker rebuilds*

---

## Introduction: From Clueless to Confident

Let me be honest upfront: when I started building this OpenTelemetry observability lab, I was completely clueless. I had a vision of what I wanted—a full-stack monitoring system with distributed tracing, metrics, and log aggregation—but the gap between vision and reality felt insurmountable.

This is the story of how I went from staring at cryptic error messages to running a production-grade observability stack. It's a story of:
- **Errors** that made no sense until they suddenly did
- **ChatGPT and Claude** becoming my patient pair-programming partners
- **Trial and error** that felt like one step forward, two steps back
- **Small victories** that compounded into major wins
- **Lessons learned** that I wish I'd known on day one

If you're reading this because you're also feeling lost in the observability wilderness, take heart. By the end, you'll understand not just *how* to build this stack, but *why* each piece matters and how to troubleshoot when (not if) things break.

Let's dive in.

---

## The Vision: What I Wanted to Build

Before we get to the struggles, let me paint the picture of what I was aiming for:

**The Goal**: A comprehensive observability lab that demonstrates:
1. **Distributed Tracing** - Follow a single user request from browser through backend to database
2. **Metrics Collection** - Track request rates, error rates, and latency percentiles
3. **Log Aggregation** - Centralize logs with full trace correlation
4. **Unified Visualization** - See everything in Grafana with seamless navigation between traces, metrics, and logs
5. **SLI/SLO Implementation** - Measure and monitor service level objectives
6. **CI/CD Integration** - Automated testing in my Jenkins DevSecOps pipeline

**The Stack**:
- **Application**: Flask backend + JavaScript frontend (simple task manager)
- **Instrumentation**: OpenTelemetry (Python SDK + Browser SDK)
- **Collection**: OpenTelemetry Collector (the telemetry hub)
- **Storage**: Grafana Tempo (traces), Prometheus (metrics), Loki (logs)
- **Visualization**: Grafana (unified dashboard)
- **Orchestration**: Docker Compose (local development)

Simple, right? *Narrator: It was not simple.*

---

## Act 1: The First Battle - "Working Outside of Application Context"

### The Error

I had ChatGPT help me set up the initial Flask application with OpenTelemetry instrumentation. Excited, I ran `docker compose up -d` and watched the containers start.

Then I checked the backend logs:

```bash
$ docker logs flask-backend

Traceback (most recent call last):
  File "/app/app.py", line 96, in <module>
    SQLAlchemyInstrumentor().instrument(engine=db.engine)
RuntimeError: Working outside of application context.
```

My heart sank. What does "application context" even mean?

### The Struggle

I spent the next hour:
1. Reading Flask documentation about application contexts
2. Googling variations of "SQLAlchemy OpenTelemetry outside application context"
3. Finding Stack Overflow posts from 2018 that were close but not quite right
4. Trying random solutions that made things worse

The problem? I was trying to access `db.engine` at module import time, before Flask's application context existed. But here's the thing—I didn't even know what "module import time" meant in this context.

### The Breakthrough

Claude helped me understand the lifecycle:

1. Python imports `app.py`
2. Flask app is created: `app = Flask(__name__)`
3. SQLAlchemy is initialized: `db = SQLAlchemy(app)`
4. **My code tried to access `db.engine` here** ← TOO EARLY!
5. Flask application context doesn't exist yet
6. BOOM - RuntimeError

The solution was elegant once I understood it:

```python
# Create Flask app and SQLAlchemy instance
app = Flask(__name__)
db = SQLAlchemy(app)

# Later... wrap in application context
with app.app_context():
    # NOW db.engine is accessible
    SQLAlchemyInstrumentor().instrument(engine=db.engine)
    db.create_all()
```

### The Lesson

**Frameworks have lifecycles.** Understanding *when* objects become available is crucial. Don't just copy-paste code—understand the execution flow.

**Personal note**: This was my first "aha!" moment. Suddenly Flask made more sense. Contexts aren't magic; they're just a way to manage application state during different phases.

---

## Act 2: The Database Disappears

### The Error

After fixing the application context issue, I got a new error:

```bash
sqlite3.OperationalError: unable to open database file
```

Wait, the database file doesn't exist? But I created it! I could see it in my local directory!

### The Struggle

This one was frustrating because I *knew* I had created the database. I could `ls` and see `tasks.db` right there. But the container couldn't find it.

I tried:
- Different volume mount configurations
- Creating the file manually before starting the container
- Giving the file 777 permissions (yes, I was desperate)

Nothing worked.

### The Breakthrough

Claude pointed out something I hadn't considered: **relative vs. absolute paths in containers**.

My code had:
```python
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///data/tasks.db'
```

That's a **relative path** (3 slashes). It resolves relative to the current working directory. But in a Docker container, the working directory could be anywhere.

The fix:
```python
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////app/data/tasks.db'
```

Four slashes! The fourth slash makes it an **absolute path** starting from root.

Also needed:
```python
os.makedirs('/app/data', exist_ok=True)  # Absolute path
```

### The Lesson

**In containers, always use absolute paths.** Relative paths are a recipe for "works on my machine" syndrome. Containers have their own filesystem; don't make assumptions.

**Personal note**: This taught me to think about code from the container's perspective, not my host machine's perspective. Subtle but important mindset shift.

---

## Act 3: The Phantom Code Cache

### The Error

After fixing the database path, I rebuilt the container:

```bash
$ docker compose up -d
$ docker logs flask-backend
RuntimeError: Working outside of application context.
```

Wait. WHAT? I just fixed that! I opened `app.py` and confirmed my fix was there. The code was definitely correct.

But the container was still running the old, broken code.

### The Struggle

This was maddening. I tried:
- Restarting the container: `docker compose restart backend`
- Stopping and starting: `docker compose stop backend && docker compose start backend`
- Checking if I had saved the file (I had)
- Questioning reality

The code on disk was correct. The running code was wrong. How is that possible?

### The Breakthrough

**Docker layer caching.** Docker caches image layers to speed up builds. If the Dockerfile hasn't changed, it uses the cached image—even if the files copied into it have changed.

The nuclear option that worked:

```bash
$ docker compose build --no-cache backend
$ docker compose up -d
```

`--no-cache` forces Docker to rebuild from scratch, ignoring all cached layers.

### The Lesson

**Docker caching is aggressive.** When debugging, don't assume "rebuild" means "rebuild from scratch." Sometimes you need to explicitly tell Docker to forget everything it knows.

**Pro tip**: For development, add to `docker-compose.yml`:
```yaml
environment:
  - PYTHONDONTWRITEBYTECODE=1  # Prevents .pyc files
  - PYTHONUNBUFFERED=1          # Real-time logs
```

**Personal note**: This was the most frustrating bug because the solution was "turn it off and on again, but harder." Sometimes the simplest fixes are the hardest to accept.

---

## Act 4: The Network Resolution Mystery

### The Error

Container started successfully! No more crashes! I checked the logs:

```bash
$ docker logs flask-backend
urllib3.exceptions.NameResolutionError: Failed to resolve 'otel-collector'
```

The Flask app couldn't find the OpenTelemetry Collector. But they're on the same Docker network. Service discovery should "just work."

### The Struggle

I verified:
- Both containers on same network: ✅
- Collector is running: ✅
- Can ping from my host to both containers: ✅

But backend couldn't reach collector. DNS wasn't resolving the service name.

I tried:
- Restarting just the backend container
- Checking Docker network configuration
- Changing the endpoint URL in every possible way

### The Breakthrough

The issue was **stale DNS state** from partial container restarts. Docker's embedded DNS server had gotten confused about which containers existed.

The fix:

```bash
$ docker compose down      # Tears down containers AND network
$ docker compose up -d     # Recreates everything fresh
```

Not `docker compose restart`. Not `docker compose stop/start`. Full teardown and recreation.

### The Lesson

**When Docker networking gets weird, burn it all down.** Docker DNS can get into inconsistent states, especially during development when you're constantly restarting things. `docker compose down` is your friend.

**Personal note**: I learned to not fight Docker when it gets confused. Sometimes the fastest solution is the most dramatic one.

---

## Act 5: The Silent Logs

### The Error

Traces were flowing into Tempo: ✅
Metrics were appearing in Prometheus: ✅
Logs in Loki: ❌ (Empty. Nothing. Nada.)

I queried Loki directly:

```bash
$ curl "http://localhost:3100/loki/api/v1/query?query={service_name=\"flask-backend\"}"
{
  "status": "success",
  "data": {
    "result": []
  }
}
```

Loki was running. It accepted queries. It just had no data.

### The Struggle

I checked:
- Backend logs (going to stdout, looked normal)
- Collector logs (no mention of log exports)
- Loki logs (no ingestion activity)

Nowhere in the pipeline was I seeing log data flow. But traces and metrics worked fine!

### The Breakthrough

Face-palm moment: **I never configured the backend to export logs via OTLP.**

My code had:
```python
# Traces - ✅ Configured
tracer_provider = TracerProvider(resource=resource)
otlp_trace_exporter = OTLPSpanExporter(...)

# Metrics - ✅ Configured
meter_provider = MeterProvider(...)

# Logs - ❌ Only going to stdout
logger = logging.getLogger()
```

I needed to add the **entire OTLP Logs SDK**:

```python
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

# Setup Logs - Export to OTLP
logger_provider = LoggerProvider(resource=resource)
set_logger_provider(logger_provider)

otlp_log_exporter = OTLPLogExporter(
    endpoint=f"{os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')}/v1/logs"
)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(otlp_log_exporter)
)

# Bridge stdlib logging to OTel
otel_log_handler = LoggingHandler(
    level=logging.INFO,
    logger_provider=logger_provider
)
logging.getLogger().addHandler(otel_log_handler)
```

After this, logs flowed: Backend → Collector → Loki ✅

### The Lesson

**Three pillars = three configurations.** Don't assume logs work because traces work. Each pillar (traces, metrics, logs) needs explicit SDK setup.

**Personal note**: This taught me to verify each component independently. Assumptions kill debugging speed.

---

## Act 6: The Label Labyrinth

### The Error

Logs were in Loki, but when I tried to query by service:

```bash
$ curl "http://localhost:3100/loki/api/v1/labels"
{
  "data": ["exporter", "instance", "job", "level"]
}
```

Where's `service_name`? I need to filter logs by service! The Grafana "Logs for this span" feature wasn't working because the service label didn't exist.

### The Struggle

I researched Loki label configuration in the OpenTelemetry Collector. Found documentation showing:

```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      resource:
        service.name: "service_name"
```

Added this. Restarted collector. Got:

```bash
Error: invalid keys: labels
```

Wait, what? The documentation shows `labels`! I tried different syntax variations. Every attempt: same error.

### The Breakthrough

**Version mismatch.** The `labels` configuration was **deprecated in v0.57** and **removed in v0.76+** of the OpenTelemetry Collector.

My collector version:
```bash
$ docker compose exec otel-collector /otelcontribcol --version
otelcol-contrib version 0.91.0
```

Version 0.91.0 was from November 2023. The `labels` config was already removed.

**Modern approach: Attribute Hints**

The new way (v0.76+):

```yaml
processors:
  resource:
    attributes:
      - key: loki.resource.labels
        value: service.name, service.instance.id, deployment.environment
        action: insert

  attributes/logs:
    actions:
      - key: loki.attribute.labels
        value: level
        action: insert

exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    # No 'labels' config! Attribute hints do the work
```

I upgraded to v0.96.0 and applied the new configuration. Finally:

```bash
$ curl "http://localhost:3100/loki/api/v1/labels"
{
  "data": [
    "deployment_environment",
    "exporter",
    "instance",
    "job",
    "level",
    "service_instance_id",
    "service_name"  ← FINALLY!
  ]
}
```

Query success:
```bash
$ curl "http://localhost:3100/loki/api/v1/query_range?query={service_name=\"flask-backend\"}"
# Returns logs! 🎉
```

### The Lesson

**OpenTelemetry evolves rapidly.** Configuration patterns change between versions. Documentation can lag. Always:
1. Check your component versions
2. Look for version-specific documentation
3. Search for "breaking changes" in release notes

**Personal note**: This was the final boss fight. Solving it felt like graduating from novice to intermediate. I learned to not trust outdated docs blindly.

---

## Victory: What I Built

After all those battles, here's what emerged:

### A Fully Functional Observability Stack

**Request Flow**:
```
User Browser
    ↓ (HTTP + W3C Trace Context headers)
Flask Backend
    ↓ (OTLP: traces, metrics, logs)
OpenTelemetry Collector
    ├── Tempo (traces)
    ├── Prometheus (metrics)
    └── Loki (logs)
          ↓
    Grafana (unified view)
```

**Capabilities**:
1. **Distributed Tracing**
   - Follow a request from browser click to database query
   - See parent-child span relationships
   - Identify performance bottlenecks

2. **SLI/SLO Metrics**
   - Availability: `(total_requests - errors) / total_requests * 100`
   - P95 Latency: `histogram_quantile(0.95, http_request_duration_seconds_bucket)`
   - Error Rate: `rate(http_errors_total[5m])`

3. **Correlated Logs**
   - Every log has trace_id and span_id
   - Click span → see related logs
   - Click log → see full trace

4. **Grafana Magic**
   - "Logs for this span" - jump from trace to logs
   - "Trace ID" links in logs - jump from log to trace
   - Exemplars in metrics - jump from latency spike to actual slow trace

### Real-World Impact

This isn't just a lab exercise. I can now:

**Debug Production Issues**:
- User reports "app is slow" → Check traces → Find slow database query → Optimize
- Error rate spike → View error traces → See exception details → Fix bug

**Monitor SLOs**:
- Define: "99% of requests must complete in <500ms"
- Alert when: P95 latency > 500ms for 5 minutes
- Visualize: Error budget burn-down chart

**Understand System Behavior**:
- Which endpoints are slowest?
- What's the distribution of database query times?
- How do errors propagate through the system?

---

## Integration: CI/CD Pipeline

The final piece was integrating this into my Jenkins DevSecOps pipeline. Now every build:

1. **Spins up observability stack**
   ```bash
   docker compose up -d tempo loki prometheus otel-collector grafana
   ```

2. **Deploys application with OTel instrumentation**
   ```bash
   docker compose up -d backend frontend
   ```

3. **Generates test traffic**
   ```bash
   for i in {1..100}; do
     curl http://localhost:5000/api/tasks -X POST -d '{...}'
   done
   ```

4. **Validates telemetry**
   ```bash
   # Check traces exist
   curl "http://localhost:3200/api/search?tags=service.name=flask-backend"

   # Verify SLI metrics
   curl 'http://localhost:9090/api/v1/query?query=http_requests_total'

   # Confirm logs ingested
   curl "http://localhost:3100/loki/api/v1/labels"
   ```

5. **Enforces SLOs**
   ```bash
   # Fail build if availability < 99%
   # Fail build if P95 latency > 500ms
   ```

6. **Generates report**
   - Trace count
   - Error rate
   - P95 latency
   - Log volume
   - Artifacts: Grafana dashboard exports

**Result**: Every code change is automatically tested for observability and performance regression.

---

## Lessons Learned: The Big Picture

Looking back at this journey, here are the meta-lessons that transcend specific technical issues:

### 1. Falling Forward Works

Every error taught me something:
- Application context error → Understanding Flask lifecycle
- Database path error → Thinking from container's perspective
- Docker cache error → Not trusting "rebuild" blindly
- DNS error → When to nuke and pave
- Missing logs → Verifying each component independently
- Label error → Checking versions, reading release notes

Each "failure" was actually a step forward. I'm not clueless anymore.

### 2. AI Assistants Are Powerful Teachers

ChatGPT and Claude didn't just give me solutions—they:
- Explained *why* the error happened
- Showed me *how* to debug systematically
- Taught me *concepts* (contexts, lifecycles, protocols)
- Gave me *confidence* to keep trying

The key was asking good follow-up questions:
- "Why did that fix work?"
- "How would I debug this in production?"
- "What's the underlying concept here?"

### 3. Documentation is Your Future Self's Best Friend

I documented every issue and solution as I went. Now when I (inevitably) encounter these again:
- I have a reference guide
- I remember the context
- I can help others faster

This blog post? It's my future self's cheat sheet.

### 4. Complexity is Conquerable in Small Pieces

The full stack felt overwhelming:
- OpenTelemetry (5 SDKs to configure)
- Collector (dozens of config options)
- Tempo (new query language - TraceQL)
- Prometheus (PromQL queries)
- Loki (LogQL + label design)
- Grafana (provisioning, datasources, correlation)

But I conquered it by:
1. Fixing one error at a time
2. Understanding one component before moving to the next
3. Verifying each piece independently
4. Building up knowledge incrementally

**Start small. Compound knowledge.**

### 5. Production-Ready Takes Time

This lab represents:
- ~40 hours of work
- 100+ docker compose restarts
- Dozens of configuration iterations
- Multiple version upgrades
- Countless Google searches

But now I have:
- A robust, production-grade stack
- Deep understanding of observability
- Reusable patterns for future projects
- Confidence to troubleshoot issues

**The initial time investment pays dividends.**

---

## What's Next: Production Deployment

This lab is ready for production with some hardening:

### Security
- [ ] Enable TLS for all OTLP connections
- [ ] Add authentication to Grafana
- [ ] Sanitize PII from spans and logs
- [ ] Use secrets manager for API keys

### Scalability
- [ ] Run multiple collector instances
- [ ] Switch Tempo to S3 backend
- [ ] Implement Prometheus with Thanos
- [ ] Enable Loki distributed mode

### Reliability
- [ ] Add tail-based sampling (reduce costs)
- [ ] Configure retry and backpressure
- [ ] Set up alerting on collector health
- [ ] Implement data retention policies

### Integration
- [ ] Deploy with Kubernetes
- [ ] Add service mesh (Istio) integration
- [ ] Connect to existing monitoring systems
- [ ] Integrate with PagerDuty/Slack

---

## Conclusion: From Clueless to Confident

When I started this journey, I could barely get the Flask app to start without crashing. Now I have:

✅ **A production-grade observability stack**
- Distributed tracing with OpenTelemetry
- SLI/SLO metrics in Prometheus
- Correlated logs in Loki
- Unified visualization in Grafana

✅ **Deep understanding**
- How telemetry flows through the system
- Why each component matters
- How to troubleshoot when things break
- When to optimize vs. when to ship

✅ **Automated validation**
- CI/CD pipeline integration
- Automated telemetry testing
- SLO enforcement in builds
- Performance regression detection

✅ **Transferable skills**
- Systematic debugging process
- Docker troubleshooting techniques
- Reading version-specific documentation
- Working with AI coding assistants

Most importantly: **Confidence.** I'm no longer clueless. I'm ready to instrument my blog project, deploy to production, and finally *see* what's happening inside my applications.

---

## For Readers: Your Turn

If you're on a similar journey, here's my advice:

### Start Now
Don't wait until you understand everything. Start with the basic stack. Break things. Fix them. Learn.

### Use AI Assistants
ChatGPT and Claude aren't cheating—they're multipliers. Use them to:
- Understand error messages
- Learn concepts
- Explore alternatives
- Validate solutions

### Document Everything
Write down:
- Problems you encounter
- Solutions that work
- Why they work
- Lessons learned

Your future self will thank you.

### Embrace Errors
Every error is a lesson in disguise:
- "Application context" → Framework lifecycles
- "Unable to open database" → Container filesystems
- "Name resolution failed" → Docker networking
- "Invalid keys" → Version compatibility

**Errors are your teachers.**

### Fall Forward
You will:
- Get stuck
- Feel frustrated
- Question if it's worth it
- Consider giving up

But if you keep pushing, each error teaches you something. Each fix makes you stronger. Each victory builds confidence.

**Falling forward is still moving forward.**

---

## Resources

**This Lab**:
- GitHub: `otel-observability-lab/` (all code, configs, docs)
- Implementation Guide: `IMPLEMENTATION-GUIDE.md` (technical deep-dive)
- Quick Reference: `QUICK-REFERENCE.md` (cheat sheet)

**Learning**:
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/)
- [Prometheus](https://prometheus.io/docs/)
- [Grafana Loki](https://grafana.com/docs/loki/)

**Community**:
- [CNCF Slack #opentelemetry](https://cloud-native.slack.com/)
- [Grafana Community](https://community.grafana.com/)

---

## Final Thoughts

Building this observability lab was one of the most challenging and rewarding technical projects I've undertaken. It pushed me out of my comfort zone, forced me to learn new concepts, and gave me skills that will serve me for years.

If you're reading this and feeling overwhelmed by observability, take heart. I was there. I got through it. You will too.

Start small. Ask questions. Document everything. Fall forward.

And when you finally see that first trace appear in Grafana, correlated with its logs and metrics, you'll feel the same rush I felt: **This is powerful. This is useful. This was worth it.**

Now go build something observable. Your future self will thank you.

---

**Author**: Wally
**Date**: October 13, 2025
**Project**: OpenTelemetry Observability Lab
**Status**: Production Ready ✅
**Next**: Integrating with Jenkins DevSecOps pipeline for blog project

---

*P.S. - To ChatGPT and Claude: Thank you for being patient teachers. You helped me transform confusion into clarity, errors into education, and struggles into success. This lab exists because you never gave up on explaining things one more time, one more way, until it clicked.*

*To future readers: May your containers always start, your traces always propagate, and your error budgets never burn. Happy observing!* 🔭📊🚀
