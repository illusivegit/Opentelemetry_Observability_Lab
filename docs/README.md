# Documentation Index

## 🚀 Current Phase: Phase 1 - Docker Compose Stack
**Status:** ✅ Complete
**Last Updated:** 2025-10-20
**Next Phase:** Phase 2 - Security & Policy 

---

## Quick Navigation

### 🎯 New to this project?
1. Start with **[Project README](../README.md)** in root directory
2. Read **[Phase 1 Architecture](phase-1-docker-compose/ARCHITECTURE.md)** for system overview
3. Follow **[Implementation Guide](phase-1-docker-compose/IMPLEMENTATION-GUIDE.md)** to deploy
4. Use **[Deployment Verification](phase-1-docker-compose/deployment-verification.md)** to validate

### 🔧 Need to troubleshoot?
- **[Troubleshooting Playbooks](phase-1-docker-compose/troubleshooting/)** for common issues
- **[Design Decisions](phase-1-docker-compose/DESIGN-DECISIONS.md)** for architectural rationale

### 📚 Learning observability concepts?
- **[Observability Fundamentals](cross-cutting/observability-fundamentals.md)** - Three Pillars, SLI/SLO
- **[TraceQL Reference](cross-cutting/traceql-reference.md)** - Query language guide

---

## 📖 Documentation by Phase

### Phase 1: Docker Compose Foundation ✅ Complete

**Scope:** On-prem VM, Docker Compose, Jenkins CI/CD, full observability stack

| Document | Purpose | Status |
|----------|---------|--------|
| **[Architecture](phase-1-docker-compose/ARCHITECTURE.md)** | Complete system design from infrastructure to application | ✅ 1,461 lines |
| **[Design Decisions](phase-1-docker-compose/DESIGN-DECISIONS.md)** | All architectural choices with trade-offs and rationale | ✅ 1,382 lines |
| **[Implementation Guide](phase-1-docker-compose/IMPLEMENTATION-GUIDE.md)** | Step-by-step deployment and configuration | ✅ 2,754 lines |
| **[Journey](phase-1-docker-compose/JOURNEY.md)** | The story of building this (failures, breakthroughs, lessons) | ✅ 843 lines |
| **[Deployment Verification](phase-1-docker-compose/deployment-verification.md)** | Post-deployment validation checklist | ✅ 631 lines |
| **[Nginx Proxy Options](phase-1-docker-compose/nginx-proxy-pass-options.md)** | Reverse proxy design (proxy vs. CORS) | ✅ 252 lines |
| **[Troubleshooting](phase-1-docker-compose/troubleshooting/)** | Operational playbooks for common issues | ✅ 1 playbook |

**Key Components:**
- Infrastructure: KVM/QEMU/libvirt on Debian 13
- CI/CD: Jenkins with Docker agents, SSH deployment
- Application: Flask backend, Nginx frontend, SQLite database
- Observability: OpenTelemetry → Tempo (traces), Prometheus (metrics), Loki (logs)
- Visualization: Grafana dashboards (SLI/SLO, traces)

---

### Phase 2: Security & Policy 📋 Planned

**Scope:** OPA/Rego, SonarQube, Snyk, Trivy, JFrog Artifactory, server hardening

**Planned Start:** Q1 2026
**Estimated Duration:** 3 months

**Documentation Plan:**
- [x] Templates ready in `/docs/templates/`
- [ ] Architecture outline (to be created)
- [ ] Design decisions (to be documented as made)
- [ ] Implementation guide (to be written during work)
- [ ] Troubleshooting playbooks (to be added as issues found)

**Key Additions:**
- Policy as Code: OPA/Rego enforcement in Jenkins pipeline
- SAST: SonarQube integration
- Dependency Scanning: Snyk for vulnerabilities
- Container Scanning: Trivy for image analysis
- Artifact Management: JFrog Artifactory
- Server Hardening: fail2ban, UFW firewall, 2FA

---

### Phase 3: Kubernetes Migration 💭 Concept

**Scope:** K8s cluster, Helm charts, StatefulSets, PostgreSQL, service mesh

**Planned Start:** Q2 2026
**Estimated Duration:** 6 months

**Key Changes:**
- Docker Compose → Kubernetes manifests
- SQLite → PostgreSQL StatefulSet
- On-prem K8s cluster (kubeadm)
- Helm charts for observability stack
- Possible Istio/Linkerd service mesh

---

### Phase 4: Hybrid Cloud 🌥️ Future

**Scope:** AWS EKS / GCP GKE, managed services, multi-region

**Timeline:** 2026 H2

---

### Phase 5: Advanced Topics ⭐ Long-term

**Scope:** Ansible, bare metal, complex networking

**Timeline:** 2027+

---

## 🔧 Cross-Cutting Documentation

**Applies to all phases**

| Document | Purpose | Size |
|----------|---------|------|
| **[Observability Fundamentals](cross-cutting/observability-fundamentals.md)** | Three Pillars (traces, metrics, logs), SLI/SLO, OpenTelemetry basics | 15,000 words |
| **[TraceQL Reference](cross-cutting/traceql-reference.md)** | Query language guide for Tempo | 4,000 words |

**Planned:**
- [ ] PromQL Reference (Prometheus queries)
- [ ] LogQL Reference (Loki queries)
- [ ] Security Baseline (SSH, fail2ban, firewall)

---

## 📖 Operational Playbooks

**Runbooks for common operations**

**Current:**
- (Playbooks will be added as operational needs arise)

**Planned:**
- [ ] Incident Response
- [ ] Rollback Procedure
- [ ] Backup & Restore
- [ ] Disaster Recovery

---

## 📐 Templates

**For creating new phase documentation**

Located in: `docs/templates/`

| Template | Purpose | Usage |
|----------|---------|-------|
| **[ARCHITECTURE-template.md](templates/ARCHITECTURE-template.md)** | Comprehensive architecture documentation | Copy for each new phase |
| **[DESIGN-DECISIONS-template.md](templates/DESIGN-DECISIONS-template.md)** | Structured decision documentation | Use for all significant decisions |
| **[troubleshooting-template.md](templates/troubleshooting-template.md)** | Operational playbook format | One per issue/problem |

**How to use:**
```bash
# Starting Phase 2
mkdir -p docs/phase-2-security-scanning/troubleshooting
cp docs/templates/ARCHITECTURE-template.md docs/phase-2-security-scanning/ARCHITECTURE.md
# Fill in the template
```

---

## 📊 Documentation Statistics

**Total Documentation:** 133,000+ words

**By Phase:**
- **Phase 1:** 127,000 words (complete)
- **Cross-cutting:** 19,000 words (growing)
- **Templates:** 3,000 words (guides for future)

**File Count:**
- Documentation files: 11
- Templates: 3
- Troubleshooting playbooks: 1

---

## 🔗 External References

### Project Infrastructure
- [GitHub Repository](https://github.com/illusivegit/Opentelemetry_Observability_Lab)
- [Main README](../README.md)

### Technology Documentation
- [OpenTelemetry](https://opentelemetry.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/)
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/)

### Learning Resources
- [Google SRE Book](https://sre.google/books/)
- [Observability Engineering Book](https://www.oreilly.com/library/view/observability-engineering/9781492076438/)

---

## 🎯 Documentation Standards

### File Naming
- **Phase docs:** `phase-X-descriptive-name/`
- **Core files:** `ARCHITECTURE.md`, `DESIGN-DECISIONS.md`, `IMPLEMENTATION-GUIDE.md`
- **Troubleshooting:** `troubleshooting/issue-name.md`

### File Size Limits
| Type | Max Lines | Action When Exceeded |
|------|-----------|----------------------|
| ARCHITECTURE.md | 1,000 | Split by domain |
| IMPLEMENTATION-GUIDE.md | 1,500 | Create sub-guides |
| DESIGN-DECISIONS.md | 1,000 | Archive old decisions |
| Troubleshooting | 200 | One issue per file |

### Design Decision IDs
- **Format:** `DD-{phase}-{number}`
- **Examples:** `DD-1-001`, `DD-2-015`, `DD-3-042`
- **Benefit:** Clear phase association

---

## 🔄 Documentation Workflow

### Adding New Phase

1. **Create directory:**
   ```bash
   mkdir -p docs/phase-X-name/troubleshooting
   ```

2. **Copy templates:**
   ```bash
   cp docs/templates/*.md docs/phase-X-name/
   ```

3. **Fill in content:**
   - Architecture: What's new, integration with previous phase
   - Design Decisions: DD-X-001, DD-X-002, etc.
   - Implementation: Step-by-step guide

4. **Update this index:**
   - Add phase to table above
   - Update statistics
   - Link to phase docs

### Adding Troubleshooting Playbook

1. **Copy template:**
   ```bash
   cp docs/templates/troubleshooting-template.md \
      docs/phase-X-name/troubleshooting/issue-name.md
   ```

2. **Fill in:**
   - Problem symptoms
   - Root cause
   - Solution steps
   - Prevention measures

3. **Link from phase README** (when created)

---

---

## 🆘 Need Help?

### Finding Information

**"How do I deploy Phase 1?"**
→ [Phase 1 Implementation Guide](phase-1-docker-compose/IMPLEMENTATION-GUIDE.md)

**"Why was X chosen over Y?"**
→ [Phase 1 Design Decisions](phase-1-docker-compose/DESIGN-DECISIONS.md)

**"Component X is broken, how do I fix it?"**
→ [Phase 1 Troubleshooting](phase-1-docker-compose/troubleshooting/)

**"What is distributed tracing?"**
→ [Observability Fundamentals](cross-cutting/observability-fundamentals.md)

**"How do I write TraceQL queries?"**
→ [TraceQL Reference](cross-cutting/traceql-reference.md)

---
