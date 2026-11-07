# Loki & Promtail Observability Setup

## Overview

The observability stack collects, indexes, and visualizes NGINX application logs deployed via Nomad.

Components:
- **Loki 2.9.0:** Log aggregation engine using TSDB schema and local filesystem storage. Bound to `127.0.0.1:3100`.
- **Promtail 2.9.0:** Log collection agent discovering containers via the Docker daemon socket (`unix:///var/run/docker.sock`) filtered by Nomad job metadata (`com.hashicorp.nomad.job_id=nginx-app`). Configured with supplementary group GID 986 to preserve unprivileged UID 10001 execution.
- **Grafana 10.2.0:** Log exploration UI bound to `127.0.0.1:3000`. Automated datasource provisioning via `grafana-datasources.yaml` pre-configures Loki as default datasource.

## Startup Instructions

```bash
cd monitoring
docker compose up -d
docker compose ps
```

Verify service readiness:
```bash
# Verify Loki readiness probe
curl -s http://127.0.0.1:3100/ready

# Verify Promtail targets
curl -s http://127.0.0.1:9080/targets

# Verify Grafana health
curl -s http://127.0.0.1:3000/api/health
```

## Label Set Applied

Promtail extracts and attaches low-cardinality labels to each log stream:
- `job=nginx`: Static workload identifier.
- `container`: Normalized Docker container name (leading slash stripped).
- `nomad_alloc_id`: Extracted from Docker label `com.hashicorp.nomad.alloc_id`.
- `service`: Extracted from Docker label `com.hashicorp.nomad.job_id` (`nginx-app`).

## LogQL Queries

### 1. Ingested NGINX Access Logs
```logql
{job="nginx"}
```

### 2. Filter Deliberate 404 Requests
```logql
{job="nginx"} |= "404"
```

### 3. Parse and Filter Non-200 Responses
```logql
{job="nginx"} | pattern `<ip> - - [<_>] "<method> <path> HTTP/<_>" <status> <_>` | status != "200"
```

## Security & Operational Design Decisions

1. **Non-Root Execution and Docker Socket Risk:** Promtail runs as non-root user `promtail` (UID 10001). To access `/var/run/docker.sock` (mode 0660, owned by `root:docker`), the container is granted supplementary group access (`group_add: ["986"]`) rather than running as root inside the container. However, Docker socket access is highly privileged and can provide effective root-level control over the host. This configuration is not a complete least-privilege security boundary.
2. **Loopback Port Binding:** Both Loki (`127.0.0.1:3100`) and Grafana (`127.0.0.1:3000`) are explicitly bound to `127.0.0.1` to prevent unauthenticated administrative access from the local network.
3. **Automated Datasource Provisioning:** Datasource configuration is committed as code (`grafana-datasources.yaml`) and mounted read-only into Grafana, ensuring immediate availability of the Loki datasource without manual UI setup.
4. **Target Isolation:** Promtail uses Docker engine-level filtering (`com.hashicorp.nomad.job_id=nginx-app`) to avoid scraping unrelated host or platform containers.
