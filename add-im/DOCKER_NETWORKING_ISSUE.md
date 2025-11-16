# Docker Networking Issue: Internet to Cluster Traffic

## Problem Description

When running containerized applications (like Hurl in Docker) that need to access Kubernetes services via port-forwards, there's a networking isolation issue:

**Symptom:**
- Port-forwards work from the host machine (`localhost:4000` ✅)
- Same port-forwards fail from inside Docker containers (`localhost:4000` ❌)
- Error: `Connection refused` or `Failed to connect to localhost port 4000`

## Root Cause

### Network Namespace Isolation

1. **Host Machine:**
   - `kubectl port-forward` binds to `127.0.0.1` (localhost) on the host
   - Host processes can access `localhost:4000` ✅

2. **Docker Container:**
   - Each container has its own network namespace
   - `localhost` inside container = container itself, NOT the host
   - Container's `localhost` cannot reach host's `localhost` ❌

### Visual Diagram

```
┌─────────────────────────────────────────┐
│  Host Machine (Linux)                    │
│                                          │
│  ┌──────────────────────────────────┐  │
│  │ kubectl port-forward              │  │
│  │ Listening on: 127.0.0.1:4000      │  │
│  └──────────────────────────────────┘  │
│            ▲                            │
│            │ ✅ Works                   │
│            │                            │
│  ┌──────────────────────────────────┐  │
│  │ Host Process                      │  │
│  │ curl localhost:4000               │  │
│  └──────────────────────────────────┘  │
│                                          │
│  ┌──────────────────────────────────┐  │
│  │ Docker Container                  │  │
│  │  ┌────────────────────────────┐  │  │
│  │  │ Hurl Process                │  │  │
│  │  │ curl localhost:4000         │  │  │
│  │  │ ❌ Fails - connects to      │  │  │
│  │  │    container's localhost    │  │  │
│  │  └────────────────────────────┘  │  │
│  │  Network: Isolated namespace     │  │
│  │  localhost ≠ host's localhost    │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Solutions

### Solution 1: Use `host.docker.internal` (Recommended)

**What it is:**
- Special DNS name provided by Docker
- Resolves to the host machine's IP from within containers
- Works on Docker Desktop (Mac/Windows) and Linux (with `--add-host` flag)

**Implementation:**

1. **Update port-forwards to bind to all interfaces:**
   ```bash
   kubectl port-forward --address 0.0.0.0 svc/cs-1 4000:4000
   ```

2. **Use `host.docker.internal` instead of `localhost` in containers:**
   ```bash
   docker run --add-host=host.docker.internal:host-gateway \
     alpine:latest \
     wget https://host.docker.internal:4000
   ```

3. **Update application configuration:**
   - Replace `localhost` → `host.docker.internal` when running in Docker
   - Keep `localhost` when running directly on host

### Solution 2: Use Docker Host Network Mode

**Implementation:**
```bash
docker run --network host alpine:latest curl localhost:4000
```

**Pros:**
- Simple - no configuration changes needed
- Container uses host's network directly

**Cons:**
- Security risk - container shares host network
- Port conflicts possible
- Not recommended for production

### Solution 3: Run Applications Directly on Host

**Implementation:**
- Don't use Docker for the application
- Run Hurl directly on the host machine

**Pros:**
- No networking issues
- Direct access to host's localhost

**Cons:**
- Requires compatible binary (GLIBC issues)
- Less isolation

## Current Implementation

### Our Solution (X-Road Hurl Configuration)

**Problem:**
- Hurl runs in Docker (due to GLIBC compatibility)
- Needs to access CS/MSS via port-forwards
- Port-forwards bind to `localhost`

**Fix Applied:**

1. **Port-forward script** (`setup_port_forwards.sh`):
   ```bash
   kubectl port-forward --address 0.0.0.0 svc/cs-1 4000:4000
   ```
   - Binds to `0.0.0.0` (all interfaces) instead of `127.0.0.1`

2. **Hurl script** (`run_config.sh`):
   ```bash
   # Detect Docker usage
   if [ "$USE_DOCKER" = true ]; then
       # Replace localhost with host.docker.internal
       export cs_host="host.docker.internal"
       export ss0_host="host.docker.internal"
   fi
   
   # Docker run with host.docker.internal support
   docker run --add-host=host.docker.internal:host-gateway \
     orangeopensource/hurl:1.8.0 \
     hurl --variable cs_host=host.docker.internal ...
   ```

**Result:**
- ✅ Port-forwards accessible from Docker containers
- ✅ No code changes needed in Hurl scripts
- ✅ Works transparently for users

## Technical Details

### Network Namespaces

**Linux Network Namespace:**
- Isolated network stack per container
- Own IP addresses, routing tables, firewall rules
- `localhost` is namespace-specific

**Docker Bridge Network:**
- Containers on `bridge` network can reach host via gateway IP
- Default gateway: `172.17.0.1` (usually)
- `host.docker.internal` maps to this gateway

### `host.docker.internal` Support

**Docker Desktop (Mac/Windows):**
- Built-in support
- Automatically resolves to host

**Linux:**
- Requires `--add-host=host.docker.internal:host-gateway`
- `host-gateway` is special Docker keyword
- Maps to Docker bridge gateway IP

## Verification

### Test from Host:
```bash
curl -k https://localhost:4000
# Should return HTML response
```

### Test from Docker Container:
```bash
# Without fix
docker run --rm alpine:latest wget -O- https://localhost:4000
# ❌ Fails: Connection refused

# With fix
docker run --rm --add-host=host.docker.internal:host-gateway \
  alpine:latest wget -O- https://host.docker.internal:4000
# ✅ Works: Returns HTML response
```

## Best Practices

1. **Always bind port-forwards to `0.0.0.0`** when containers need access:
   ```bash
   kubectl port-forward --address 0.0.0.0 svc/service 4000:4000
   ```

2. **Use `host.docker.internal`** in containerized applications:
   - Automatically detect Docker usage
   - Replace `localhost` with `host.docker.internal` when in Docker

3. **Document the networking model:**
   - Explain to DevOps teams why `localhost` doesn't work
   - Provide clear examples of correct usage

4. **Consider service mesh or ingress:**
   - For production, use proper service discovery
   - Port-forwards are for development/debugging

## References

- [Docker Networking Documentation](https://docs.docker.com/network/)
- [Docker Desktop: host.docker.internal](https://docs.docker.com/desktop/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host)
- [Kubernetes Port-Forward](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#port-forward)

---

**Last Updated:** 2025-11-05  
**Issue:** Docker containers cannot access host's `localhost` services  
**Solution:** Use `host.docker.internal` with `--add-host` flag

