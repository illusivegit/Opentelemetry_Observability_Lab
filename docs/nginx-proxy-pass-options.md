# Nginx `proxy_pass` with Variables: Option 1 vs Option 2

## The Problem We're Solving

When using Docker Compose, container IPs change on every rebuild/restart. Nginx normally resolves upstream hostnames **once at startup** and caches the IP forever. This causes 502 errors when the backend container gets a new IP after `docker compose restart backend`.

**Solution:** Use Docker's embedded DNS (`127.0.0.11`) + a **variable** in `proxy_pass` to force Nginx to re-resolve the backend hostname on every request.

---

## The Gotcha: Variables Change Nginx Behavior

When you use a **variable** in `proxy_pass`, Nginx **ignores any URI path** you add after the variable. This is counterintuitive and is the source of confusion.

### Example of the Trap

```nginx
# What you might expect:
set $backend http://backend:5000;
proxy_pass $backend/api/;  # ❌ The "/api/" is IGNORED!
```

You'd expect Nginx to append `/api/` to the upstream request, but **it doesn't**. The URI part is silently ignored when using a variable.

---

## Option 1: Keep `/api` Prefix (Recommended for Our Setup)

**What it does:** Passes the full original URI (e.g., `/api/tasks`) to the backend unchanged.

### Configuration

```nginx
resolver 127.0.0.11 ipv6=off valid=30s;

location /api/ {
  set $backend_upstream http://backend:5000;
  proxy_pass $backend_upstream;     # ✅ Sends /api/tasks to backend
  proxy_connect_timeout 5s;
  proxy_read_timeout 60s;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Request Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          OPTION 1: Keep /api Prefix                     │
└─────────────────────────────────────────────────────────────────────────┘

Client Request:
  GET http://192.168.122.250/api/tasks
       │
       ├──────────────────────────────────────────────────┐
       │                                                  │
       ▼                                                  ▼
  ┌────────────────┐                               ┌────────────────┐
  │  Nginx (port   │  location /api/               │  Flask Backend │
  │  80)           │  matches                      │  (port 5000)   │
  │                │                               │                │
  │  Variable:     │  proxy_pass $backend_upstream │  Flask Route:  │
  │  $backend =    │  (no URI specified)           │  @app.route(   │
  │  backend:5000  │                               │    '/api/tasks'│
  │                │  ──────────────────────────►  │  )             │
  │                │  Proxies to:                  │                │
  │                │  http://backend:5000/api/tasks│  Receives:     │
  │                │                               │  /api/tasks    │
  └────────────────┘                               └────────────────┘
       │                                                  │
       │                                                  │
       └──────────────────────────────────────────────────┘
                Response flows back unchanged

✅ Original URI preserved: /api/tasks → /api/tasks
✅ Flask sees the full /api/... path it expects
✅ No rewrite rules needed
```

### Why This Works for Us

Our Flask backend defines routes **with** the `/api` prefix:

```python
# backend/app.py
@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    ...

@app.route('/api/tasks', methods=['POST'])
def create_task():
    ...
```

Since Flask expects `/api/tasks`, we should send `/api/tasks` from Nginx. Option 1 does exactly that.

---

## Option 2: Strip `/api` Prefix (Not Needed, But Here for Comparison)

**What it does:** Removes `/api` from the URI before proxying to backend.

### Configuration

```nginx
resolver 127.0.0.11 ipv6=off valid=30s;

location /api/ {
  rewrite ^/api/(.*)$ /$1 break;    # ❌ Extra complexity
  set $backend_upstream http://backend:5000;
  proxy_pass $backend_upstream;     # Sends /tasks (no /api)
  proxy_connect_timeout 5s;
  proxy_read_timeout 60s;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Request Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       OPTION 2: Strip /api Prefix                       │
└─────────────────────────────────────────────────────────────────────────┘

Client Request:
  GET http://192.168.122.250/api/tasks
       │
       ├──────────────────────────────────────────────────┐
       │                                                  │
       ▼                                                  ▼
  ┌────────────────┐                               ┌────────────────┐
  │  Nginx (port   │  location /api/               │  Flask Backend │
  │  80)           │  matches                      │  (port 5000)   │
  │                │                               │                │
  │  Rewrite:      │  rewrite ^/api/(.*)$ /$1 break│  Flask Route:  │
  │  /api/tasks    │  (/api/tasks → /tasks)        │  @app.route(   │
  │  → /tasks      │                               │    '/tasks'    │
  │                │  proxy_pass $backend_upstream │  )             │
  │  Variable:     │                               │                │
  │  $backend =    │  ──────────────────────────►  │  Receives:     │
  │  backend:5000  │  Proxies to:                  │  /tasks        │
  │                │  http://backend:5000/tasks    │  (no /api)     │
  └────────────────┘                               └────────────────┘
       │                                                  │
       │                                                  │
       └──────────────────────────────────────────────────┘
                Response flows back unchanged

⚠️  URI rewritten: /api/tasks → /tasks
⚠️  Flask would need routes WITHOUT /api prefix
⚠️  Extra rewrite rule adds complexity
```

### When You'd Use This

Option 2 is useful if your backend routes are defined **without** the `/api` prefix:

```python
# Hypothetical backend that expects routes WITHOUT /api
@app.route('/tasks', methods=['GET'])  # ← No /api prefix
def get_tasks():
    ...
```

In this case, you'd strip `/api` in Nginx so Flask sees `/tasks` instead of `/api/tasks`.

---

## Side-by-Side Comparison

| Aspect | Option 1: Keep `/api` | Option 2: Strip `/api` |
|--------|----------------------|------------------------|
| **Client Request** | `GET /api/tasks` | `GET /api/tasks` |
| **Nginx Rewrite** | None | `rewrite ^/api/(.*)$ /$1 break;` |
| **URI Sent to Backend** | `/api/tasks` | `/tasks` |
| **Flask Route Needed** | `@app.route('/api/tasks')` | `@app.route('/tasks')` |
| **Complexity** | ✅ Simple | ⚠️ Extra rewrite rule |
| **Matches Our Setup** | ✅ Yes (our Flask uses `/api/...`) | ❌ No (would break routing) |

---

## Why We Chose Option 1

1. **Matches existing Flask routes:** Our backend already uses `/api/tasks`, `/api/smoke/db`, etc.
2. **Simpler config:** No rewrite rules needed.
3. **Explicit behavior:** The URI path is transparent—what the client sends is what Flask receives.
4. **Easier to debug:** `proxy_pass $backend_upstream` with no URI manipulation is straightforward.

---

## Key Takeaway: Variables Ignore URI Parts

Remember this rule:

```nginx
# ❌ WRONG (URI part ignored):
set $backend http://backend:5000;
proxy_pass $backend/api/;  # The "/api/" does NOTHING

# ✅ CORRECT (use rewrite if you need to manipulate URI):
set $backend http://backend:5000;
proxy_pass $backend;        # Passes original URI as-is
```

If you need to change the URI when using a variable, use `rewrite` **before** `proxy_pass`.

---

## Testing the Fix

After applying Option 1 and restarting the frontend container:

```bash
# 1. Reload Nginx to pick up new config
docker compose -p lab restart frontend

# 2. Verify DNS resolution works
docker compose -p lab exec frontend getent hosts backend
# Should show: 172.18.0.X  backend (current IP)

# 3. Test API from within frontend container
docker compose -p lab exec frontend wget -qO- http://backend:5000/api/tasks
# Should return JSON task list

# 4. Test from your host machine (through Nginx proxy)
curl http://192.168.122.250/api/tasks
# Should return JSON task list

# 5. Verify Prometheus scrape target is UP
# Open Grafana → Connections → Data Sources → Prometheus → Status → Targets
# Confirm "flask-backend" shows UP
```

---

## Files Changed

- `frontend/default.conf`: Implemented Option 1 (dynamic DNS with variable, no URI rewrite)

---

## References

- [Nginx proxy_pass documentation](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)
- [Docker Compose networking](https://docs.docker.com/compose/networking/)
- [Nginx resolver directive](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)
