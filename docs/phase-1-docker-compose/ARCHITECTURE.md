# System Architecture: On-Premises Observability Lab

## From Theory to Practice: Building a Production-Grade Monitoring Stack

**Version:** 2.0
**Status:** Production-Ready Proof of Concept
**Last Updated:** 2025-10-20

---

## Executive Summary

This document captures the complete architecture of a battle-tested, production-grade observability stack built as a **proof of concept for an on-premises infrastructure simulation**. This project represents the foundation of my "On-Prem Domain" — a comprehensive learning environment designed to bridge the gap between cloud-native principles and traditional on-premises infrastructure management.

### What This Project Represents

This isn't just an observability lab. It's:

- **A Simulated On-Premises Environment** running on KVM/QEMU/libvirt virtualization
- **A CI/CD Testing Ground** deployed via Jenkins pipeline to a dedicated VM
- **A Migration Experimentation Platform** for testing cloud migration strategies
- **A Production Architecture Blueprint** demonstrating SRE best practices
- **A Foundation for Future Growth** (Kubernetes, Ansible, service mesh, hybrid cloud)

### The Journey Ahead

This proof of concept is the **first milestone** in a larger vision:

1. **Current State (You Are Here):** Docker Compose observability stack on VM
2. **Phase 2:** Policy as Code (OPA/Rego), advanced SAST/DAST, artifact management
3. **Phase 3:** Kubernetes migration, Ansible automation, complex networking
4. **Phase 4:** Hybrid cloud implementation using the 5 R's migration strategies
5. **Phase 5:** Self-hosted production infrastructure on bare metal

---

## Table of Contents

1. [Infrastructure Foundation](#infrastructure-foundation)
2. [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
3. [Application Architecture](#application-architecture)
4. [Observability Architecture](#observability-architecture)
5. [Network Architecture](#network-architecture)
6. [Design Decisions](#design-decisions)
7. [System Integration](#system-integration)
8. [Production Deployment](#production-deployment)
9. [Future Roadmap](#future-roadmap)

---

## Infrastructure Foundation

### The On-Premises Simulation Stack

This project runs on a **virtualized on-premises environment** that simulates enterprise infrastructure:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PHYSICAL HOST (Debian 13)                        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                   KVM Hypervisor (Kernel-based VM)                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                        QEMU/Libvirt                         │  │  │
│  │  │  • User-space VM management                                 │  │  │
│  │  │  • I/O emulation (disk, network, CPU)                       │  │  │
│  │  │  • Hardware virtualization (Intel VT-x/AMD-V)               │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      Libvirt Management Layer                     │  │
│  │  • Unified API for VM lifecycle management                        │  │
│  │  • Virtual network configuration (virbr0 bridge)                  │  │
│  │  • Storage pool management                                        │  │
│  │  • XML-based VM definitions                                       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Management Tools                               │  │
│  │  • virt-manager (GUI) - Visual VM management                      │  │
│  │  • virsh (CLI) - Command-line VM operations                       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                  Virtual Network Infrastructure                   │  │
│  │  • Bridge Networking (virbr0) - VM-to-VM communication            │  │
│  │  • NAT Network - External internet access                         │  │
│  │  • Virtual NICs (tap devices) - Per-VM network interfaces         │  │
│  │  • DNS Resolution - Container service discovery                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Storage Management                             │  │
│  │  • Storage Pools - Filesystem, LVM, NFS                           │  │
│  │  • Virtual Volumes - qcow2/raw disk images                        │  │
│  │  • Snapshot Support - VM state preservation                       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                  Security & Isolation                             │  │
│  │  • AppArmor/SELinux - MAC security policies                       │  │
│  │  • User Permissions - libvirt group access control                │  │
│  │  • Network Isolation - Per-VM network segmentation                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   GUEST VMs (Running on Hypervisor)                     │
│                                                                         │
│  ┌──────────────────────┐         ┌──────────────────────┐             │
│  │  Jenkins VM          │         │  Application VM      │             │
│  │  (192.168.122.x)     │         │  (192.168.122.250)   │             │
│  │                      │         │                      │             │
│  │  • Jenkins Controller│────────▶│  • Docker Engine     │             │
│  │  • Docker Agents     │  Deploy │  • Observability App │             │
│  │  • HashiCorp Vault   │         │  • Prometheus/Grafana│             │
│  └──────────────────────┘         └──────────────────────┘             │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why This Architecture?

**Enterprise Realism:**
- Mirrors real-world on-prem environments (VMware ESXi, Proxmox, Hyper-V patterns)
- Simulates bare-metal → hypervisor → VM → container stack
- Provides networking complexity similar to production data centers

**Flexibility:**
- Easy to snapshot/clone VMs for testing
- Isolated environments prevent "dev broke prod" scenarios
- Can simulate multi-datacenter topologies

**Cost-Effective:**
- No cloud provider bills for learning/experimentation
- Complete control over infrastructure
- Directly applicable to self-hosted environments

---

## CI/CD Pipeline Architecture

### Jenkins Deployment Pipeline

The observability application is deployed via a **containerized Jenkins setup** with inbound Docker agents:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      JENKINS CONTROL PLANE                              │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                  Docker Network: jenkins-net                      │  │
│  │  (User-defined bridge for service discovery & stable DNS)         │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Jenkins Controller (jenkins/jenkins:lts-jdk17)                  │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  Persistent Storage: jenkins_home volume                   │  │   │
│  │  │  • Job definitions (XML configs)                           │  │   │
│  │  │  • Build history & artifacts                               │  │   │
│  │  │  • Installed plugins                                        │  │   │
│  │  │  • Credentials (encrypted)                                  │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  │  Exposed Ports:                                                  │   │
│  │  • 8080: HTTP UI/API                                            │   │
│  │  • 50000: JNLP inbound agent connection                         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Inbound Docker Agent (custom image with jq, docker, rsync)     │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  Runtime Configuration:                                    │  │   │
│  │  │  • Connects via JNLP to controller:50000                   │  │   │
│  │  │  • Authenticates with static agent secret                  │  │   │
│  │  │  • Executes pipeline stages in isolated workspace          │  │   │
│  │  │  • Mounted Docker socket for DinD operations               │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  HashiCorp Vault (vault-server)                                 │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  Secrets Management:                                       │  │   │
│  │  │  • KV secrets engine                                       │  │   │
│  │  │  • File storage backend (vault_server_volume)              │  │   │
│  │  │  • HTTP listener on 0.0.0.0:8200 (TLS disabled for dev)    │  │   │
│  │  │  • Integration with Jenkins via plugin/CLI                 │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  │  Exposed Ports:                                                  │   │
│  │  • 8200: HTTP API & UI                                          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Current Pipeline Flow (Jenkinsfile)

```groovy
pipeline {
  agent { label 'docker-agent1' }

  environment {
    VM_USER    = 'deploy'
    VM_IP      = '192.168.122.250'      // Target VM for deployment
    DOCKER_CTX = 'vm-lab'                // Remote Docker context
    PROJECT    = 'lab'                   // Docker Compose project name
    VM_DIR     = '/home/deploy/lab/app' // Deployment directory on VM
  }

  stages {
    stage('Checkout Code') {
      // Clone from GitHub: illusivegit/Opentelemetry_Observability_Lab
    }

    stage('Sanity on agent') {
      // Verify SSH, Docker, Docker Compose availability
    }

    stage('Ensure remote Docker context') {
      // Create SSH-based Docker context pointing to VM
      // Enables: docker --context vm-lab commands
    }

    stage('Sync repo to VM') {
      // rsync entire repository to VM (bind mounts require local files)
      // Ensures docker-compose.yml and all configs are present
    }

    stage('Debug: verify compose paths') {
      // Validate file structure on VM before deployment
    }

    stage('Compose up (remote via SSH)') {
      // SSH into VM, run: PROJECT=<name> LAB_HOST=<host> ./start-lab.sh (defaults: "lab", "localhost")
      // DOCKER_BUILDKIT=1 for optimized image builds
    }

    stage('Smoke tests') {
      // Verify service health:
      //   - Frontend: http://192.168.122.250:8080
      //   - Grafana: http://192.168.122.250:3000/login
      //   - Prometheus: http://192.168.122.250:9090/-/ready
    }
  }

  post {
    failure {
      // Log hint for troubleshooting remote container logs
    }
  }
}
```

### Key Pipeline Design Decisions

**1. SSH-Based Deployment (Not Docker Context API)**
- **Why:** VM doesn't expose Docker daemon over network (security)
- **How:** `sshagent` with SSH keys, `rsync` for file sync
- **Benefit:** Works with standard SSH hardening (no 2375 port exposure)

**2. Remote File Sync (rsync)**
- **Why:** Docker Compose bind mounts require files to exist on VM filesystem
- **Example:** `frontend/default.conf` mounted into Nginx container
- **Tradeoff:** Adds ~5 seconds to pipeline, eliminates "file not found" errors

**3. Docker Context for Verification**
- **Creation:** `docker context create vm-lab --docker "host=ssh://deploy@192.168.122.250"`
- **Use Case:** Allows `docker --context vm-lab ps` from Jenkins
- **Future:** Could replace SSH commands entirely (exploring for Phase 2)

**4. Healthcheck-Based Orchestration**
- **Backend healthcheck:** Python-based `/metrics` endpoint validation
- **Frontend dependency:** `depends_on: backend (service_healthy)`
- **Result:** Eliminates race condition where Nginx starts before backend DNS resolves

**5. SSH Security Hardening (Key-Only Authentication)**
- **Implementation:** ED25519 key-based authentication, password auth disabled
- **Why ED25519:** Smaller keys (256-bit), faster operations, modern standard
- **Process:**
  1. Generate key pair: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_jenkins`
  2. Temporarily set password on `deploy` user for key installation
  3. Copy public key: `ssh-copy-id -i ~/.ssh/id_ed25519_jenkins.pub deploy@192.168.122.250`
  4. Lock password: `sudo passwd -l deploy`
  5. Disable password auth in `/etc/ssh/sshd_config`
  6. Restart SSH daemon
- **Result:** Production-grade security, eliminates brute-force attack vector
- **Learning Value:** Walked through full hardening process (not just copy-paste key) to build security muscle memory
- **Future Hardening (Phase 2):**
  - fail2ban for intrusion prevention
  - UFW firewall configuration
  - SSH 2FA with Google Authenticator PAM
  - Key rotation policy (90-day cycle)
  - Resource: [How To Secure A Linux Server](https://github.com/imthenachoman/How-To-Secure-A-Linux-Server)

---

## Application Architecture

### Monitoring Application Stack

The deployed application is a **full-stack task manager** instrumented for observability:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     APPLICATION DEPLOYMENT (VM)                         │
│  IP: 192.168.122.250                                                    │
│  Network: otel-network (Docker bridge)                                  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        FRONTEND TIER                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Nginx (nginx:alpine) - Port 8080 (host) → 80 (container)        │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Static File Serving:                                       │  │  │
│  │  │  • /usr/share/nginx/html/index.html (Task Manager UI)       │  │  │
│  │  │  • /usr/share/nginx/html/app.js (Dynamic API calls)         │  │  │
│  │  │  • /usr/share/nginx/html/styles.css (Responsive design)     │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Reverse Proxy (Solves CORS):                               │  │  │
│  │  │  location /api/ {                                           │  │  │
│  │  │    resolver 127.0.0.11 ipv6=off valid=30s;  # Docker DNS   │  │  │
│  │  │    set $backend_upstream http://backend:5000;               │  │  │
│  │  │    proxy_pass $backend_upstream;  # Variable-based routing  │  │  │
│  │  │    proxy_set_header X-Real-IP $remote_addr;                 │  │  │
│  │  │  }                                                           │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  Dynamic Link Generation (app.js):                               │  │
│  │  • Grafana: http://${window.location.hostname}:3000              │  │
│  │  • Prometheus: http://${window.location.hostname}:9090           │  │
│  │  → Works on localhost, VM IP, or cloud hostname                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ HTTP /api/* → backend:5000/api/*
┌─────────────────────────────────────────────────────────────────────────┐
│                         BACKEND TIER                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Flask API (Python 3.11) - Port 5000                             │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Application Framework:                                     │  │  │
│  │  │  • Flask 3.0 - Lightweight web framework                    │  │  │
│  │  │  • Flask-SQLAlchemy 3.1.1 - ORM layer                       │  │  │
│  │  │  • Flask-CORS - Cross-origin support                        │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  RESTful API Endpoints:                                     │  │  │
│  │  │  • GET    /api/tasks         - List all tasks               │  │  │
│  │  │  • POST   /api/tasks         - Create task                  │  │  │
│  │  │  • PUT    /api/tasks/:id     - Update task                  │  │  │
│  │  │  • DELETE /api/tasks/:id     - Delete task                  │  │  │
│  │  │  • GET    /api/simulate-slow - Performance testing          │  │  │
│  │  │  • GET    /api/simulate-error - Error injection             │  │  │
│  │  │  • GET    /api/smoke/db      - DB load generation           │  │  │
│  │  │  • GET    /metrics           - Prometheus metrics           │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Instrumentation Layer (3 Pillars):                         │  │  │
│  │  │                                                              │  │  │
│  │  │  ① TRACES (OpenTelemetry SDK)                               │  │  │
│  │  │    • FlaskInstrumentor: HTTP request/response spans         │  │  │
│  │  │    • SQLAlchemyInstrumentor: DB query spans                 │  │  │
│  │  │    • OTLP Exporter → otel-collector:4318/v1/traces          │  │  │
│  │  │                                                              │  │  │
│  │  │  ② METRICS (Prometheus Client)                              │  │  │
│  │  │    • prom_http_requests_total (Counter)                     │  │  │
│  │  │    • prom_http_request_duration_seconds (Histogram)         │  │  │
│  │  │    • prom_http_errors_total (Counter)                       │  │  │
│  │  │    • prom_db_query_duration_seconds (Histogram)             │  │  │
│  │  │    • Exposed at /metrics for Prometheus scraping            │  │  │
│  │  │                                                              │  │  │
│  │  │  ③ LOGS (OpenTelemetry SDK)                                 │  │  │
│  │  │    • Structured JSON logging (stdlib logging)               │  │  │
│  │  │    • Automatic trace_id/span_id injection                   │  │  │
│  │  │    • OTLP Exporter → otel-collector:4318/v1/logs            │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Critical Design Fix: Application Context                   │  │  │
│  │  │  Problem: SQLAlchemy event listeners caused RuntimeError    │  │  │
│  │  │  Solution:                                                   │  │  │
│  │  │    def before_cursor_execute(...):  # Plain function        │  │  │
│  │  │        # Record query start time                            │  │  │
│  │  │                                                              │  │  │
│  │  │    with app.app_context():  # Activate Flask context       │  │  │
│  │  │        event.listen(db.engine, 'before_cursor_execute', ...) │  │  │
│  │  │        event.listen(db.engine, 'after_cursor_execute', ...)  │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ SQLAlchemy ORM
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA TIER                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  SQLite Database                                                  │  │
│  │  Path: /app/data/tasks.db (absolute path - critical!)            │  │
│  │  Volume: backend-data (named volume for persistence)              │  │
│  │                                                                   │  │
│  │  Schema:                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │  Table: tasks                                               │  │  │
│  │  │  • id: INTEGER PRIMARY KEY AUTOINCREMENT                    │  │  │
│  │  │  • title: VARCHAR(100) NOT NULL                             │  │  │
│  │  │  • description: TEXT                                        │  │  │
│  │  │  • completed: BOOLEAN DEFAULT 0                             │  │  │
│  │  │  • created_at: DATETIME DEFAULT CURRENT_TIMESTAMP           │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  Instrumentation:                                                 │  │
│  │  • Every query captured by SQLAlchemyInstrumentor                 │  │
│  │  • Query duration tracked via event listeners:                    │  │
│  │    - before_cursor_execute: Start timer                           │  │
│  │    - after_cursor_execute: Calculate duration, emit metric        │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Architecture Wins

**1. Nginx Reverse Proxy (Not CORS Headers)**
- **Problem:** Browser CORS blocking `http://vm:8080 → http://vm:5000` API calls
- **Option A (Rejected):** Add CORS headers to Flask (complexity, preflight requests)
- **Option B (Chosen):** Nginx `/api/*` proxy to `backend:5000`
- **Result:** Same-origin requests, no CORS complexity, production-ready pattern

**2. Dynamic DNS Resolution in Nginx**
- **Problem:** Cached IP for `backend` became stale when container restarted → 502 errors
- **Solution:** `resolver 127.0.0.11` + variable-based `proxy_pass`
- **Magic:** Nginx re-resolves DNS on every request, eliminates stale cache

**3. Healthcheck-Driven Startup Ordering**
- **Problem:** Frontend started before backend → DNS lookup failed → 502 errors
- **Solution:** Backend Python healthcheck + `depends_on: service_healthy`
- **Result:** Frontend waits until backend is truly ready, not just "started"

---

## Observability Architecture

### The Three Pillars: Separation of Concerns

**Critical Design Decision:** After encountering metric duplication (same metric from OTel SDK *and* Prometheus client), I implemented **Option A: Single Source Per Pillar**:

```
┌──────────────────────────────────────────────────────────────────┐
│              OBSERVABILITY INSTRUMENTATION                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PILLAR 1: TRACES (OpenTelemetry)                                │
│  • FlaskInstrumentor: HTTP spans                                 │
│  • SQLAlchemyInstrumentor: DB query spans                        │
│  • Export: OTLP → Collector → Tempo                             │
│                                                                  │
│  PILLAR 2: METRICS (Prometheus Client)                           │
│  • prometheus_client library (NOT OTel SDK)                      │
│  • http_requests_total, http_request_duration_seconds            │
│  • Export: /metrics → Prometheus scrape                          │
│  • Rationale: SLI metrics don't need OTel enrichment             │
│                                                                  │
│  PILLAR 3: LOGS (OpenTelemetry)                                  │
│  • Structured JSON logging                                       │
│  • Automatic trace_id/span_id injection                          │
│  • Export: OTLP → Collector → Loki                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Complete Observability Data Flow

```
USER REQUEST (POST /api/tasks)
     │
     ▼
┌────────────────────────────────────────────────────────────────┐
│  FRONTEND (Nginx)                                              │
│  • Proxies to backend:5000                                     │
└────┬───────────────────────────────────────────────────────────┘
     │
     ▼
┌────────────────────────────────────────────────────────────────┐
│  FLASK BACKEND                                                 │
│                                                                │
│  @app.before_request:                                          │
│  • Start timer: g.prom_start_time = time.time()               │
│  • Log: "Incoming request" (with trace_id)                    │
│  • OTel creates root span                                     │
│                                                                │
│  Route Handler (create_task):                                 │
│  • OTel custom span: "create_task"                            │
│  • Set span attribute: task.title="Example"                   │
│  • db.session.add(new_task)                                   │
│  • db.session.commit() ──────────────┐                        │
│                                       │                        │
│  @app.after_request:                  │                        │
│  • Calculate duration                 │                        │
│  • prom_http_requests_total.inc()     │                        │
│  • prom_http_request_duration.observe(duration)                │
│  • Log: "Request completed" (with trace_id, duration)          │
│  • OTel closes spans                  │                        │
└────┬──────────────────────────────────┬─────────────────────────┘
     │                                  │
     │                                  ▼ (SQLAlchemy instrumentation)
     │                           ┌──────────────────────────────┐
     │                           │  DB QUERY INSTRUMENTATION    │
     │                           │  • before_cursor_execute:    │
     │                           │    - Start timer             │
     │                           │  • after_cursor_execute:     │
     │                           │    - Calculate duration      │
     │                           │    - prom_db_query_duration  │
     │                           │      .observe(duration)      │
     │                           │  • OTel span: "INSERT tasks" │
     │                           └──────────────────────────────┘
     │
     ▼ OTLP Export (background batch)
┌─────────────────────────────────────────────────────────────────┐
│  OPENTELEMETRY COLLECTOR (Port 4318)                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Receivers:                                               │  │
│  │  • otlp/grpc (4317) - High-performance binary protocol    │  │
│  │  • otlp/http (4318) - HTTP/JSON (used by Flask)           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Processors (order matters!):                             │  │
│  │  1. memory_limiter: Prevents OOM (512MB limit)            │  │
│  │  2. resource: Adds service.instance.id=$HOSTNAME          │  │
│  │  3. attributes: Enriches with environment="lab"           │  │
│  │  4. attributes/logs: Promotes attributes to Loki labels   │  │
│  │  5. batch: Aggregates before export (10s timeout)         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Exporters:                                               │  │
│  │  • otlp/tempo: Traces → tempo:4317                        │  │
│  │  • loki: Logs → loki:3100/loki/api/v1/push                │  │
│  │  • logging: Debug output (sampled)                        │  │
│  │  ❌ NO Prometheus exporters (eliminated duplication)      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
     │
     ├─ Traces ─────────▶ TEMPO (Port 3200)
     │                    • Parquet format storage
     │                    • TraceQL query engine
     │                    • Trace-to-log correlation
     │
     └─ Logs ──────────▶ LOKI (Port 3100)
                         • Labels: {service_name, level}
                         • LogQL query engine
                         • Derived fields for trace links

     METRICS (Separate Path)
     │
     ▼ Prometheus Scrape (15s interval)
┌─────────────────────────────────────────────────────────────────┐
│  PROMETHEUS (Port 9090)                                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Scrape Targets:                                          │  │
│  │  • flask-backend:5000/metrics (job="flask-backend")       │  │
│  │  • otel-collector:8888 (collector internal metrics)       │  │
│  │  • tempo:3200, loki:3100, grafana:3000 (self-monitoring)  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  TSDB Storage:                                            │  │
│  │  • Retention: 15 days                                     │  │
│  │  • Compression: Gorilla + Snappy                          │  │
│  │  • Volume: prometheus-data                                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│  GRAFANA (Port 3000)                                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Data Sources (Provisioned):                              │  │
│  │  • Prometheus (uid: prometheus) - SLI/SLO queries         │  │
│  │  • Tempo (uid: tempo) - Distributed tracing               │  │
│  │  • Loki (uid: loki) - Log aggregation                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Dashboards:                                              │  │
│  │  • SLI/SLO Dashboard - Task Manager                       │  │
│  │    - Service Availability: (1 - errors/total) * 100      │  │
│  │    - P95 Latency: histogram_quantile(0.95, ...)          │  │
│  │    - Request Rate: rate(http_requests_total[5m])         │  │
│  │    - DB P95 Latency: histogram_quantile(0.95,            │  │
│  │        db_query_duration_seconds_bucket[5m])             │  │
│  │                                                           │  │
│  │  • End-to-End Tracing Dashboard                          │  │
│  │    - Service dependency map                              │  │
│  │    - Trace timeline visualization                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Correlation Features:                                    │  │
│  │  • Trace → Logs: Click "Logs for this span" in Tempo     │  │
│  │  • Logs → Trace: Click trace_id in Loki log entry        │  │
│  │  • Metrics → Traces: (Future) Exemplars for latency spikes│ │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Architecture Works

**Problem Solved: Metric Duplication**
- **Before:** Same metric appeared twice in Prometheus (different `job` labels)
- **Root Cause:** OTel SDK metrics + Prometheus client metrics both active
- **Solution:** Removed OTel metric pipeline, kept Prometheus client only
- **Tradeoff:** Lost OTel metric enrichment, but gained simplicity
- **Justification:** SLI metrics (counters/histograms) don't need OTel processing

**Traces Still Provide Context**
- Distributed tracing (the real value of OTel) fully preserved
- Database query spans show operation type, duration, SQL statement
- Correlation via trace_id works perfectly

**Logs Flow Through Collector**
- Structured JSON logs with trace_id/span_id
- Loki labels automatically extracted via attribute hints
- LogQL queries like `{service_name="flask-backend"} |= "trace_id"`

---

## Network Architecture

### Multi-Layer Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PHYSICAL NETWORK (Host)                          │
│  • Public IP: (varies by host)                                      │
│  • Private LAN: 192.168.1.0/24 (example home network)               │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LIBVIRT VIRTUAL NETWORK                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Bridge: virbr0                                               │  │
│  │  • Type: NAT mode                                             │  │
│  │  • Subnet: 192.168.122.0/24                                   │  │
│  │  • DHCP Range: 192.168.122.2 - 192.168.122.254               │  │
│  │  • Gateway: 192.168.122.1 (host bridge)                       │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  DNS Resolution:                                              │  │
│  │  • Provided by libvirt dnsmasq                                │  │
│  │  • VM hostname → IP mapping                                   │  │
│  │  • Forwarding to host DNS for external resolution            │  │
│  └───────────────────────────────────────────────────────────────┘  │
└──────────────┬───────────────────────────────┬──────────────────────┘
               │                               │
               ▼                               ▼
    ┌──────────────────┐             ┌──────────────────┐
    │  Jenkins VM      │             │  Application VM  │
    │  192.168.122.x   │             │  192.168.122.250 │
    └──────────────────┘             └────────┬─────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   DOCKER BRIDGE NETWORK (otel-network)              │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Network Driver: bridge                                       │  │
│  │  • Subnet: 172.18.0.0/16 (Docker default range)               │  │
│  │  • Gateway: 172.18.0.1                                        │  │
│  │  • DNS: 127.0.0.11 (Docker embedded DNS server)               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Container Service Discovery:                                 │  │
│  │  • backend → 172.18.0.7 (example)                             │  │
│  │  • frontend → 172.18.0.8                                      │  │
│  │  • otel-collector → 172.18.0.9                                │  │
│  │  • prometheus → 172.18.0.10                                   │  │
│  │  • tempo, loki, grafana → (other IPs)                         │  │
│  │                                                                │  │
│  │  Resolution:                                                   │  │
│  │  • Containers use DNS name (e.g., backend)                    │  │
│  │  • Docker DNS resolves to container IP                        │  │
│  │  • TTL: 30 seconds (for dynamic updates)                      │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Port Mappings (host:container):                              │  │
│  │  • 8080:80 (frontend HTTP)                                    │  │
│  │  • 5000:5000 (backend API)                                    │  │
│  │  • 3000:3000 (Grafana UI)                                     │  │
│  │  • 9090:9090 (Prometheus UI)                                  │  │
│  │  • 3200:3200 (Tempo API)                                      │  │
│  │  • 3100:3100 (Loki API)                                       │  │
│  │  • 4317:4317 (OTLP gRPC)                                      │  │
│  │  • 4318:4318 (OTLP HTTP)                                      │  │
│  │  • 13133:13133 (Collector healthcheck)                        │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Network Communication Patterns

**Internal Container Communication:**
```
frontend (Nginx) ──────> backend:5000 (Flask)
                            │
                            ├──> otel-collector:4318 (OTLP)
                            └──> SQLite (local file)

otel-collector ──────> tempo:4317 (traces)
                ├─────> loki:3100 (logs)
                └─────> (NO prometheus connection - scrape model instead)

prometheus ────────> backend:5000/metrics (scrape)
           ├────────> otel-collector:8888 (internal metrics)
           └────────> tempo:3200, loki:3100, grafana:3000

grafana ───────────> prometheus:9090 (PromQL queries)
        ├──────────> tempo:3200 (TraceQL queries)
        └──────────> loki:3100 (LogQL queries)
```

**External Access (from outside VM):**
```
User Browser ──> http://192.168.122.250:8080 ──> Frontend container
             └─> http://192.168.122.250:3000 ──> Grafana container
             └─> http://192.168.122.250:9090 ──> Prometheus container

Jenkins Agent ──> SSH 192.168.122.250 ──> VM Docker daemon
              └─> rsync files to /home/deploy/lab/app
```

### Critical Network Fixes Applied

**Problem 1: Nginx 502 "backend could not be resolved"**
- **Cause:** Backend container not started when Nginx started → DNS had no entry
- **Fix:** Backend healthcheck + `depends_on: service_healthy` in frontend
- **Result:** Frontend waits for backend to be healthy before starting

**Problem 2: Nginx cached stale backend IP**
- **Cause:** Nginx resolves `backend` once at startup, caches forever
- **Fix:** Dynamic DNS resolution with `resolver 127.0.0.11` + variable `$backend_upstream`
- **Result:** Nginx re-resolves DNS on every request, handles container IP changes

**Problem 3: Docker DNS confusion after partial restarts**
- **Cause:** `docker compose restart` leaves network intact, DNS state can become stale
- **Fix:** `docker compose down && docker compose up -d` (full teardown)
- **Result:** Fresh network and DNS state every deployment

---

## Design Decisions

### Decision Matrix: Key Architectural Choices

| Decision | Options Considered | Choice Made | Rationale |
|----------|-------------------|-------------|-----------|
| **Metric Export Strategy** | A) Prometheus client only<br>B) OTel SDK only<br>C) Both (with renaming) | **A** | Eliminates duplication, simpler queries, SLI metrics don't need OTel enrichment |
| **Nginx Proxy vs CORS** | A) Reverse proxy `/api/*`<br>B) Flask CORS headers | **A** | Same-origin requests, production pattern, no preflight overhead |
| **Backend Healthcheck** | A) HTTP curl<br>B) TCP port check<br>C) Python `/metrics` check | **C** | Tests actual application readiness, not just port binding |
| **SQLite Path** | A) Relative path<br>B) Absolute path | **B** | Container-safe, eliminates "database not found" errors |
| **Event Listeners** | A) Decorators<br>B) Plain functions + `event.listen()` | **B** | Avoids Flask application context errors, explicit registration |
| **DNS Resolution (Nginx)** | A) Static hostname<br>B) Dynamic with resolver directive | **B** | Handles container restarts gracefully, no 502 errors |
| **Pipeline Deployment** | A) Docker context API<br>B) SSH + rsync | **B** | Works with hardened SSH, doesn't require Docker daemon exposure |
| **Database** | A) SQLite<br>B) PostgreSQL/MySQL | **A (PoC)** | Simplicity for learning, plan to migrate to PostgreSQL in production |

### The Metric Duplication Saga

**Timeline of Discovery:**

1. **Initial Implementation:** Added OTel SDK metrics + Prometheus client
2. **First Dashboard:** Queries returned 2x expected values
3. **Investigation:** Found duplicate series with different `job` labels
4. **Root Cause:** Two parallel pipelines feeding Prometheus:
   - OTel SDK → Collector → Prometheus (via remote write + scrape)
   - Prometheus client → /metrics → Prometheus (scrape)
5. **Solution Evaluation:**
   - Option A: Remove OTel metrics (keep Prometheus client)
   - Option B: Remove Prometheus client (keep OTel metrics)
   - Option C: Rename metrics to avoid collision
6. **Decision:** Option A - Remove OTel metric pipeline
7. **Outcome:** Clean dashboards, single source of truth, no duplication

**Why Option A Won:**
- **Simplicity:** One metric source is easier to debug
- **OTel Value Preserved:** Traces (the real power) still flow through collector
- **Prometheus Client Optimized:** Purpose-built for app-level SLI metrics
- **No Dashboard Changes:** Existing queries worked immediately

---

## System Integration

### Full Request Lifecycle with Observability

**Example: User Creates a Task**

```
1. USER ACTION
   Browser: http://192.168.122.250:8080
   Click: "Add Task" button
   ↓

2. JAVASCRIPT (app.js)
   fetch('/api/tasks', {
     method: 'POST',
     body: JSON.stringify({title: "Deploy to prod", completed: false})
   })
   ↓ (Proxied by Nginx to backend:5000/api/tasks)

3. FLASK @app.before_request
   • Start timer: g.prom_start_time = time.time()
   • Log: "Incoming request POST /api/tasks" (with trace_id)
   • OTel FlaskInstrumentor creates root span
   ↓

4. ROUTE HANDLER: create_task()
   • OTel custom span: "create_task"
   • Validate input
   • Create Task object
   • db.session.add(new_task)
   • db.session.commit()
   ↓

5. SQLALCHEMY EVENT: before_cursor_execute
   • Save query start time in context
   ↓

6. DATABASE QUERY
   • Execute: INSERT INTO tasks (title, completed, created_at) VALUES (?, ?, ?)
   ↓

7. SQLALCHEMY EVENT: after_cursor_execute
   • Calculate duration: end - start = 0.0023 seconds
   • prom_db_query_duration_seconds.observe(0.0023, {operation: "INSERT"})
   • OTel SQLAlchemyInstrumentor creates span: "INSERT tasks"
   ↓

8. FLASK @app.after_request
   • Calculate request duration: time.time() - g.prom_start_time = 0.045 seconds
   • prom_http_requests_total.inc()
   • prom_http_request_duration_seconds.observe(0.045)
   • Log: "Request completed POST /api/tasks 201 0.045s" (with trace_id)
   • OTel closes all spans
   ↓

9. BACKGROUND EXPORT (Batched every 10s)
   ┌───────────────────────────────────────────┐
   │  TRACES (OTLP)                            │
   │  backend → otel-collector:4318/v1/traces  │
   │  Span tree:                               │
   │  • POST /api/tasks (45ms)                 │
   │    └─ create_task (42ms)                  │
   │       └─ INSERT tasks (2.3ms)             │
   └────────────────┬──────────────────────────┘
                    │
                    ▼
             TEMPO storage

   ┌───────────────────────────────────────────┐
   │  LOGS (OTLP)                              │
   │  backend → otel-collector:4318/v1/logs    │
   │  [                                        │
   │    {                                      │
   │      "message": "Request completed...",   │
   │      "trace_id": "a1b2c3...",             │
   │      "level": "INFO"                      │
   │    }                                      │
   │  ]                                        │
   └────────────────┬──────────────────────────┘
                    │
                    ▼
              LOKI storage
              {service_name="flask-backend"}

10. PROMETHEUS SCRAPE (15 seconds later)
    GET http://backend:5000/metrics

    Collected:
    http_requests_total{method="POST",endpoint="create_task",status_code="201"} 1
    http_request_duration_seconds_bucket{le="0.05",...} 1
    db_query_duration_seconds_bucket{le="0.005",operation="INSERT"} 1

    Stored in TSDB

11. GRAFANA VISUALIZATION (Real-time)

    SLI/SLO Dashboard:
    • Request Rate: rate(http_requests_total[5m]) → Shows spike
    • P95 Latency: histogram_quantile(0.95, ...) → 45ms
    • DB P95 Latency: histogram_quantile(0.95, db_...) → 2.3ms

    Explore → Tempo:
    • Search for traces from last 5 minutes
    • Click trace ID → See 3-span tree
    • Click "Logs for this span" → Jump to Loki logs

    Explore → Loki:
    • Query: {service_name="flask-backend"} |= "Request completed"
    • See log entry with trace_id
    • Click trace_id link → Jump back to Tempo trace
```

### Correlation in Action

**Scenario: User Reports "Application is slow"**

```
1. INVESTIGATE METRICS (Prometheus/Grafana)
   Query: rate(http_requests_total[5m])
   Finding: Request rate normal (~10 req/min)

   Query: histogram_quantile(0.95, http_request_duration_seconds_bucket[5m])
   Finding: P95 latency spiked to 2 seconds at 14:32

2. FIND SLOW TRACES (Tempo)
   Query: {duration > 1s}
   Finding: 3 traces with >1s duration
   Click slowest trace (2.1s)

   Span breakdown:
   • POST /api/tasks: 2.1s
     └─ create_task: 2.05s
        └─ INSERT tasks: 2.03s  ← BOTTLENECK!

3. CORRELATE TO LOGS (Loki)
   Click "Logs for this span" in Tempo
   Loki query auto-populated: {service_name="flask-backend"} |= "a1b2c3..."

   Log entries:
   14:32:15 INFO "Incoming request POST /api/tasks"
   14:32:17 INFO "Request completed POST /api/tasks 201 2.1s"

   Finding: No errors, just slow DB write

4. ROOT CAUSE ANALYSIS
   • Database write took 2 seconds (normally ~2ms)
   • Possible causes:
     - Disk I/O saturation (check VM host metrics)
     - Database lock contention (check concurrent requests)
     - Large transaction (check task payload size)

5. VERIFICATION
   Query: db_query_duration_seconds_bucket{operation="INSERT"}
   Finding: Only this one query was slow
   Conclusion: Transient I/O issue, not systemic problem
```

This is **the power of unified observability**: Jump seamlessly between metrics → traces → logs to diagnose issues faster than any single signal could provide.

---

## Production Deployment

### Current Deployment Flow

```
┌──────────────────────────────────────────────────────────────────┐
│  DEVELOPER WORKSTATION                                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  1. Code Development                                       │  │
│  │     • Edit backend/app.py, frontend/app.js, etc.           │  │
│  │     • Test locally with Docker Compose                     │  │
│  │     • Commit to local Git                                  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  2. Push to GitHub                                         │  │
│  │     git push origin main                                   │  │
│  │     → https://github.com/illusivegit/                      │  │
│  │       Opentelemetry_Observability_Lab                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  JENKINS CONTROLLER                                              │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  3. Pipeline Trigger (Manual for now)                      │  │
│  │     • Navigate to Jenkins UI                               │  │
│  │     • Click "Build Now" on observability-lab job           │  │
│  │     • Webhook trigger (Phase 2 roadmap)                    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  4. Checkout Code (Jenkins Agent)                          │  │
│  │     git clone https://github.com/illusivegit/...           │  │
│  │     → /var/jenkins_home/workspace/observability-lab        │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  5. Sanity Checks                                          │  │
│  │     • Verify SSH available                                 │  │
│  │     • Verify Docker CLI present                            │  │
│  │     • Verify Docker Compose present                        │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  6. Setup Remote Docker Context                            │  │
│  │     docker context create vm-lab                           │  │
│  │       --docker host=ssh://deploy@192.168.122.250           │  │
│  │     docker --context vm-lab info  # Test connection        │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼ SSH + rsync
┌──────────────────────────────────────────────────────────────────┐
│  APPLICATION VM (192.168.122.250)                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  7. Sync Files to VM                                       │  │
│  │     rsync -az --delete \                                   │  │
│  │       ./  deploy@192.168.122.250:/home/deploy/lab/app/     │  │
│  │                                                             │  │
│  │     Files copied:                                           │  │
│  │     • docker-compose.yml                                    │  │
│  │     • backend/ (app.py, Dockerfile, requirements.txt)       │  │
│  │     • frontend/ (index.html, default.conf)                  │  │
│  │     • otel-collector/ (otel-collector-config.yml, etc.)     │  │
│  │     • grafana/ (provisioning/, dashboards/)                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  8. Docker Compose Deployment (via SSH)                    │  │
│  │     ssh deploy@192.168.122.250 "                           │  │
│  │       cd /home/deploy/lab/app &&                           │  │
│  │       PROJECT=lab LAB_HOST=<vm-ip> ./start-lab.sh          │  │
│  │     "                                                       │  │
│  │                                                             │  │
│  │     Steps executed on VM:                                   │  │
│  │     • Build backend image (DOCKER_BUILDKIT=1)               │  │
│  │     • Pull Nginx, Grafana, Prometheus, etc. images          │  │
│  │     • Create otel-network bridge network                    │  │
│  │     • Start backend (waits for healthcheck)                 │  │
│  │     • Start frontend (depends on backend healthy)           │  │
│  │     • Start observability stack (collector, Tempo, etc.)    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  9. Post-Deployment State                                  │  │
│  │     Containers running:                                     │  │
│  │     • backend (flask-backend) - Up (healthy)                │  │
│  │     • frontend (nginx:alpine) - Up                          │  │
│  │     • otel-collector - Up                                   │  │
│  │     • tempo - Up                                            │  │
│  │     • prometheus - Up                                       │  │
│  │     • loki - Up                                             │  │
│  │     • grafana - Up                                          │  │
│  │                                                             │  │
│  │     Exposed services:                                       │  │
│  │     • http://192.168.122.250:8080 - Application UI          │  │
│  │     • http://192.168.122.250:3000 - Grafana                 │  │
│  │     • http://192.168.122.250:9090 - Prometheus              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  JENKINS CONTROLLER (Smoke Tests)                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  10. Health Checks (from Jenkins agent)                    │  │
│  │      curl http://192.168.122.250:8080           # Frontend  │  │
│  │      curl http://192.168.122.250:3000/login     # Grafana   │  │
│  │      curl http://192.168.122.250:9090/-/ready   # Prometheus│  │
│  │                                                             │  │
│  │      All return HTTP 200 → PIPELINE SUCCESS ✓               │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Post-Deployment Verification

After successful deployment, the following verification is performed (see `docs/phase-1-docker-compose/deployment-verification.md` for full guide):

1. **Backend Container Health:** `docker compose -p lab ps` → backend shows "Up (healthy)"
2. **DNS Resolution:** `docker exec frontend getent hosts backend` → Returns IP
3. **API Connectivity:** `curl http://192.168.122.250:8080/api/tasks` → Returns JSON
4. **Prometheus Scrape:** Check http://192.168.122.250:9090/targets → `flask-backend` UP
5. **Grafana Data Sources:** All 3 datasources show "working" status
6. **SLI Dashboards:** Panels display data after generating traffic
7. **DB Metrics:** DB P95 panel populates after running DB smoke test

---

## Future Roadmap

### Phase 2: Advanced CI/CD & Security (Planned)

**Pre-Commit Hooks (Host IDE + GitHub):**
- **Host Environment:**
  - `.pre-commit-config.yaml` with hooks:
    - `black` (Python formatting)
    - `flake8` (linting)
    - `eslint` (JavaScript linting)
    - `prettier` (frontend formatting)
    - `detect-secrets` (basic SAST)
  - Runs on `git commit` before code enters pipeline

- **GitHub Repository:**
  - Branch protection rules requiring status checks
  - Pre-receive hooks for syntax validation
  - Ensures "dirty" code never hits Jenkins

**Webhook-Triggered Pipelines:**
- GitHub webhook → Jenkins controller
- Triggers on:
  - Push to `main` branch
  - Pull request creation/update
- Eliminates manual "Build Now" clicks

**Policy as Code (OPA/Rego):**
- **Learning Phase:** Study Rego syntax, OPA policies
- **Integration Point:** New pipeline stage between "Build" and "Deploy"
- **Policies to Enforce:**
  - Container images must not run as root
  - All images must have vulnerability scan results
  - Secrets must not be hardcoded in configs
  - Resource limits must be defined (CPU, memory)
- **Tool:** Conftest CLI (OPA-based policy checking for configs)

**Example OPA Policy (rego):**
```rego
package docker_compose

deny[msg] {
  service := input.services[name]
  not service.user
  msg := sprintf("Service '%s' must define a non-root user", [name])
}
```

**Security Scanning Pipeline:**
```
┌────────────────────────────────────────────────────────────┐
│  STAGE: Build & Security Scan                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. SonarQube (SAST)                                 │  │
│  │     • Code quality analysis                          │  │
│  │     • Security vulnerabilities (SQL injection, XSS)  │  │
│  │     • Code coverage from tests                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  2. Black Box Build (Language-Native Tools)          │  │
│  │     Python: pip wheel → .whl artifact                │  │
│  │     JavaScript: npm run build → dist/ bundle         │  │
│  │     Archive artifacts for versioning                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  3. Container Image Build                            │  │
│  │     docker build -t observability-backend:$BUILD_ID  │  │
│  │     Copy artifacts into image                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  4. Snyk (Dependency Scanning)                       │  │
│  │     snyk test --severity-threshold=high              │  │
│  │     • Scans Python packages (requirements.txt)       │  │
│  │     • Scans npm packages (package.json)              │  │
│  │     • Fails build on high/critical vulnerabilities  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  5. Trivy (Container Image Scanning)                 │  │
│  │     trivy image --severity HIGH,CRITICAL \           │  │
│  │       observability-backend:$BUILD_ID                │  │
│  │     • Scans OS packages (Debian/Alpine)              │  │
│  │     • Scans application dependencies                 │  │
│  │     • Generates SBOM (Software Bill of Materials)    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  6. JFrog Artifactory (Artifact Management)          │  │
│  │     • Upload image to Artifactory Docker registry    │  │
│  │     • Tag with:                                      │  │
│  │       - observability-backend:$BUILD_ID              │  │
│  │       - observability-backend:latest                 │  │
│  │       - observability-backend:v1.2.3 (semver)        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  7. JFrog Xray (Image Compliance)                    │  │
│  │     • Scans image in Artifactory                     │  │
│  │     • Checks against security policies               │  │
│  │     • Licenses compliance (GPL, MIT, Apache)         │  │
│  │     • Operational risk (EOL dependencies)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  8. Quality Gate                                     │  │
│  │     IF (SonarQube PASS && Snyk PASS && Trivy PASS    │  │
│  │         && Xray PASS) THEN                           │  │
│  │       → Proceed to Deploy stage                      │  │
│  │     ELSE                                             │  │
│  │       → Create Jira ticket with failure details      │  │
│  │       → Fail pipeline                                │  │
│  │       → Send Slack notification to #devsecops        │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

**Jira Integration:**
- Pipeline stage failures auto-create tickets
- Ticket contents:
  - Build ID and Git commit SHA
  - Failed stage (SonarQube/Snyk/Trivy/Xray)
  - Vulnerability details with severity scores
  - Remediation suggestions (library upgrades)
- Assigned to: Security triage queue

---

### Phase 3: Kubernetes Migration (Planned)

**Rationale:**
- Current: Docker Compose (single-host orchestration)
- Goal: Kubernetes (multi-node, production-grade orchestration)
- Benefit: Hands-on K8s experience, service mesh readiness, cloud-portable architecture

**Migration Path:**
1. **Convert docker-compose.yml to Kubernetes manifests:**
   - Tool: Kompose (automated conversion)
   - Manual refinement: Add liveness/readiness probes, resource limits

2. **Helm Chart Development:**
   ```
   observability-stack/
   ├── Chart.yaml
   ├── values.yaml
   ├── templates/
   │   ├── backend-deployment.yaml
   │   ├── backend-service.yaml
   │   ├── frontend-deployment.yaml
   │   ├── ingress.yaml
   │   ├── otel-collector-deployment.yaml
   │   ├── prometheus-statefulset.yaml
   │   ├── tempo-statefulset.yaml
   │   ├── loki-statefulset.yaml
   │   └── grafana-deployment.yaml
   ```

3. **Persistent Storage:**
   - Replace Docker named volumes with PersistentVolumeClaims (PVC)
   - Backend SQLite → PostgreSQL StatefulSet with PVC
   - Prometheus, Tempo, Loki → StatefulSets with dedicated PVCs

4. **Networking:**
   - Replace Docker bridge network with Kubernetes Services (ClusterIP)
   - Add Ingress resource (Nginx Ingress Controller)
   - Service mesh (Istio/Linkerd) for automatic mTLS and observability

**Kubernetes Architecture Snapshot:**
```
┌─────────────────────────────────────────────────────────────┐
│  INGRESS (Nginx Ingress Controller)                        │
│  • http://observability.example.com → frontend:80          │
│  • http://observability.example.com/grafana → grafana:3000 │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  FRONTEND DEPLOYMENT (3 replicas)                          │
│  • Service: frontend (ClusterIP)                           │
│  • Pods: frontend-{hash}-{random}                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  BACKEND DEPLOYMENT (5 replicas with HPA)                  │
│  • Service: backend (ClusterIP)                            │
│  • Horizontal Pod Autoscaler: min 2, max 10                │
│  • Liveness: /metrics every 10s                            │
│  • Readiness: /health every 5s                             │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  POSTGRESQL STATEFULSET (3 replicas with replication)      │
│  • Service: postgres-headless (for StatefulSet DNS)        │
│  • PVCs: postgres-data-0, postgres-data-1, postgres-data-2  │
│  • Replaces SQLite for production workloads                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  OBSERVABILITY STACK (StatefulSets)                         │
│  • otel-collector: Deployment (3 replicas, stateless)      │
│  • prometheus: StatefulSet (PVC for TSDB)                  │
│  • tempo: StatefulSet (PVC for traces)                     │
│  • loki: StatefulSet (PVC for logs)                        │
│  • grafana: Deployment (ConfigMaps for dashboards)         │
└─────────────────────────────────────────────────────────────┘
```

**Service Mesh Integration (Istio):**
- Automatic sidecar injection (Envoy proxy per pod)
- Benefits:
  - Automatic distributed tracing (no code changes needed)
  - Mutual TLS between all services
  - Traffic management (canary deployments, A/B testing)
  - Circuit breaking and retries

---

### Phase 4: Hybrid Cloud Migration (Planned)

**Goal:** Implement the **5 R's of Cloud Migration** using this on-prem stack as the source:

**1. Rehost (Lift and Shift):**
- Deploy Kubernetes cluster to AWS EKS / GCP GKE / Azure AKS
- Use Helm charts from Phase 3 (minimal changes)
- Replace PVCs with cloud storage (EBS, Persistent Disks, Azure Disks)
- Update Ingress to use cloud load balancers

**2. Replatform (Lift, Tinker, and Shift):**
- Replace self-managed Prometheus → AWS Managed Prometheus (AMP) / GCP Managed Prometheus
- Replace Grafana → AWS Managed Grafana / GCP Managed Grafana
- Replace PostgreSQL → AWS RDS / Cloud SQL / Azure Database
- Keep application code identical, leverage managed services

**3. Refactor (Re-architect):**
- Decompose monolithic Flask app into microservices:
  - `task-service` (CRUD operations)
  - `auth-service` (authentication/authorization)
  - `notification-service` (async task notifications)
- Use cloud-native messaging (SQS, Pub/Sub, Service Bus)
- Replace OTLP → native cloud SDKs (X-Ray, Cloud Trace, Application Insights)

**4. Repurchase (Move to SaaS):**
- Replace self-hosted observability → Datadog / New Relic / Honeycomb
- Replace Jenkins → GitHub Actions / GitLab CI / CircleCI
- Replace Vault → AWS Secrets Manager / GCP Secret Manager / Azure Key Vault

**5. Relocate (Hypervisor-Level Lift and Shift):**
- Use AWS Application Migration Service (MGN) or Azure Migrate
- Migrate entire VMs (including KVM hypervisor layer if needed)
- No application changes, just infrastructure relocation

**Hybrid Cloud Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│  ON-PREMISES (KVM/Libvirt)                                  │
│  • Development environment                                  │
│  • Kubernetes cluster (test/staging)                        │
│  • Self-hosted runners (Jenkins agents)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ VPN / Direct Connect / ExpressRoute
                       │
┌──────────────────────┴──────────────────────────────────────┐
│  CLOUD (AWS/GCP/Azure)                                      │
│  • Production Kubernetes cluster (EKS/GKE/AKS)              │
│  • Managed services (RDS, Managed Prometheus, etc.)         │
│  • Object storage (S3, GCS, Blob Storage)                   │
│  • CI/CD runners (cloud-native)                             │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Unified Observability
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  CENTRALIZED GRAFANA                                        │
│  • Queries on-prem Prometheus (via VPN)                     │
│  • Queries cloud Managed Prometheus                         │
│  • Unified dashboards across environments                   │
└─────────────────────────────────────────────────────────────┘
```

---

### Phase 5: Advanced Topics (Planned)

**Ansible Automation:**
- Replace manual VM provisioning with Ansible playbooks
- Playbooks:
  - `provision-vm.yml` (create VM via libvirt)
  - `deploy-k8s.yml` (install Kubernetes on VMs)
  - `deploy-observability.yml` (deploy stack via Helm)

**Complex Networking:**
- Implement BGP routing between on-prem and cloud
- Multi-region deployments with latency-based routing
- Private service mesh across environments

**Bare Metal Self-Hosted Infrastructure:**
- Migrate from KVM VMs → bare metal Kubernetes
- Use tools like Talos Linux (immutable Kubernetes OS)
- Build home lab with mini PCs or rack servers
- Simulate data center operations (power, cooling, IPMI)

---

## Conclusion

### What This Architecture Represents

This observability lab is **more than a monitoring stack**—it's a **foundation for continuous learning** in modern infrastructure engineering. By building on a simulated on-premises environment, I've created a safe playground to:

- **Learn by Doing:** Every component was built through trial, error, and iteration
- **Simulate Production:** Architecture mirrors real-world enterprise stacks
- **Experiment Safely:** VMs can be snapshotted, cloned, destroyed without cloud costs
- **Build Incrementally:** Each phase adds complexity while preserving stability

### Key Architectural Wins

1. **Clean Separation of Concerns:**
   - OpenTelemetry handles distributed context (traces, logs)
   - Prometheus client handles SLI metrics
   - No duplication, no confusion

2. **Production-Ready Patterns:**
   - Nginx reverse proxy (not CORS hacks)
   - Healthcheck-based orchestration
   - Dynamic DNS resolution for resilience

3. **CI/CD Integration:**
   - Automated deployment via Jenkins
   - SSH-based security (no exposed Docker daemons)
   - Reproducible deployments

4. **Observability-First Mindset:**
   - Every request traced from browser to database
   - Logs correlated with traces via trace_id
   - Metrics provide SLI/SLO visibility

### The Journey Ahead

This proof of concept is **milestone 1** in a multi-year learning journey:

- **Phase 2:** Advanced security, policy as code, artifact management
- **Phase 3:** Kubernetes migration, service mesh, multi-node orchestration
- **Phase 4:** Hybrid cloud experimentation with 5 R's migration strategies
- **Phase 5:** Bare metal self-hosting, complex networking, Ansible automation

Each phase builds on the previous, reinforcing skills while adding new capabilities. The **on-prem domain** provides the solid foundation; the **cloud-native domain** provides the future direction.

### Final Thoughts

**What started as "build an observability lab" became:**
- A deep dive into distributed tracing, metrics, and log aggregation
- A crash course in Docker networking, DNS, and healthchecks
- A Jenkins CI/CD pipeline integrating with VM infrastructure
- A battle-tested architecture documented for future reference

**Most importantly:** Every error message, every 502 gateway error, every "database not found" taught valuable lessons. This documentation exists because the journey was messy, iterative, and real.

This is **theory to practice** in action.

---

**Document Version:** 1.0
**Author:** Wally
**Last Updated:** 2025-10-20
**Status:** Living Document (will evolve with each phase)

**License:** MIT (adapt for your own learning journey)
