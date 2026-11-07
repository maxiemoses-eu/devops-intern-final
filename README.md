# DevOps Intern Final Assessment — NGINX Platform Pipeline

[![CI Pipeline](https://github.com/maxiemoses-eu/devops-intern-final/actions/workflows/ci.yml/badge.svg)](https://github.com/maxiemoses-eu/devops-intern-final/actions/workflows/ci.yml)

- **Candidate:** Maxie Moses Adams
- **Submission Date:** 2026-11-07
- **Repository:** [https://github.com/maxiemoses-eu/devops-intern-final](https://github.com/maxiemoses-eu/devops-intern-final)

---

## 1. Architecture Overview

This project delivers an end-to-end, automated deployment and observability platform for a hardened static NGINX application.

```
+-----------------------------------------------------------------------------------+
|                                  Git Repository                                   |
|                      (feature/core-pipeline -> PR -> main)                        |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                               GitHub Actions CI/CD                                |
|  [lint: ShellCheck/Hadolint] -> [build: docker save] -> [test: load & healthcheck]|
|                                          |                                        |
|                          (push to main only)                                      |
|                                          v                                        |
|                         [publish: load & push to GHCR]                            |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        GitHub Container Registry (GHCR)                           |
|               ghcr.io/maxiemoses-eu/nginx-app:<sha> and :latest                   |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                               HashiCorp Nomad                                     |
|               - Service job scheduling with Docker task driver                    |
|               - Dynamic host port allocation (http -> 8080)                       |
|               - Resource allocation: 100 MHz CPU, 64 MB RAM                       |
|               - Rolling update: max_parallel=1, min_healthy=10s, auto_revert=true |
+-----------------------------------------------------------------------------------+
        |                                                           |
        v                                                           v
+-----------------------+                               +---------------------------+
|    HashiCorp Consul   |                               |  Container Logs (stdout)  |
| - Service registration|                               +---------------------------+
| - HTTP health check   |                                           |
|   (/healthz, 10s int) |                                           v
+-----------------------+                               +---------------------------+
                                                        |         Promtail          |
                                                        | - Docker SD (Nomad job ID)|
                                                        | - Extracts nomad_alloc_id |
                                                        +---------------------------+
                                                                    |
                                                                    v
                                                        +---------------------------+
                                                        |        Grafana Loki       |
                                                        | - TSDB index & chunks     |
                                                        +---------------------------+
                                                                    |
                                                                    v
                                                        +---------------------------+
                                                        |      Grafana Explore      |
                                                        | - Pre-provisioned Loki DS |
                                                        | - LogQL Query Dashboard   |
                                                        +---------------------------+
```

---

## 2. Prerequisites & Environment

The local application and monitoring configuration were checked in the following environment. Nomad and Consul versions below are compatibility targets, not evidence of a live cluster deployment:
- **Operating System:** Linux 6.18 (WSL2 / Ubuntu 24.04 x86_64)
- **Docker Engine:** `29.9.3` (minimum `24.0.0`)
- **Docker Compose:** `v5.7.0` (minimum `v2.20.0`)
- **HashiCorp Nomad:** `v1.7.x` / `v1.8.x` (CLI / agent)
- **HashiCorp Consul:** `v1.17.x` / `v1.18.x` (CLI / agent)
- **Python:** `3.10+` (used for lightweight local validation)
- **POSIX Shell:** `/bin/sh` (tested against `dash` and `bash`)

---

## 3. Quick Start (< 10 Commands)

To build and verify the application and monitoring services locally from a clean clone. Nomad deployment requires separate Nomad and Consul agents:

```bash
# 1. Clone repository
git clone https://github.com/maxiemoses-eu/devops-intern-final.git && cd devops-intern-final

# 2. Build hardened container image injecting real Git SHA and current date
docker build --build-arg BUILD_SHA="$(git rev-parse HEAD)" --build-arg ASSESSMENT_DATE="$(date -u +%Y-%m-%d)" -t devops-intern-final:local -f app/Dockerfile app/

# 3. Start application container on port 8080
docker run -d --rm --name nginx-app -p 8080:8080 devops-intern-final:local

# 4. Verify endpoints with healthcheck script
./scripts/healthcheck.sh http://localhost:8080/healthz

# 5. Verify root web page rendering
curl -s http://localhost:8080/ | grep -E "(Name|Date|Build)"

# 6. Start monitoring stack (Loki, Promtail, Grafana)
docker compose -f monitoring/docker-compose.yaml up -d

# 7. Verify Loki and Grafana readiness
curl -s http://127.0.0.1:3100/ready && curl -s http://127.0.0.1:3000/api/health

# 8. Clean up local resources
docker stop nginx-app && docker compose -f monitoring/docker-compose.yaml down
```

---

## 4. Task-by-Task Implementation & Verification

### Task 1 — Source Control & Git Practice
- Incremental, conventional commits (`feat:`, `ci:`, `fix:`, `docs:`, `chore:`).
- Dedicated branch: `feature/core-pipeline`.
- Merge into `main` via a reviewed Pull Request (pending).
- Submission release tag: `v1.0.0` (pending merge and final verification).
- Untracked instruction file `AGENT.md` is preserved locally and strictly omitted from commits.

### Task 2 — Linux Shell Scripting
Both scripts are located in `scripts/` and have verified executable Git permissions (`100755`):
- **`scripts/sysinfo.sh`:** Gathers system diagnostic information (user/UID, hostname, kernel, ISO-8601 date, disk, memory, Docker status). Pure POSIX `/bin/sh` (`set -eu`). The assessment mentions `set -euo pipefail`, but `pipefail` is not POSIX and is unsupported by shells such as Ubuntu Dash. These scripts retain the POSIX shebang and use `set -eu` for portability.
  ```text
  === System Information ===
  User        : maxie (UID: 1000)
  Hostname    : DESKTOP-0S7PFBM
  Kernel      : 6.18.54.1-microsoft-standard-WSL2
  Date (ISO)  : 2026-11-06T17:25:43Z

  === Disk Usage ===
  Filesystem      Size  Used Avail Use% Mounted on
  /dev/sdd       1007G  7.6G  949G   1% /

  === Memory Usage ===
                 total        used        free      shared  buff/cache   available
  Mem:           5.7Gi       2.4Gi        92Mi        30Mi       3.4Gi       3.3Gi
  Swap:          2.0Gi       3.4Mi       2.0Gi

  === Docker Daemon ===
  Docker is running
  ```
- **`scripts/healthcheck.sh`:** Robust HTTP probe with connection timeout (`--connect-timeout 3 --max-time 5`). Safely catches network connection errors without aborting under `set -e`:
  - *Positive check:* `./scripts/healthcheck.sh http://localhost:8080` -> `OK — received HTTP 200 from http://localhost:8080` (Exit 0)
  - *Negative check (404):* `./scripts/healthcheck.sh http://localhost:8080/nonexistent` -> `FAIL — received HTTP 404 from http://localhost:8080/nonexistent (expected 200)` (Exit 1)
  - *Negative check (Refused):* `./scripts/healthcheck.sh http://localhost:9999` -> `FAIL — curl failed to connect to http://localhost:9999 (exit code: 7)` (Exit 1)

### Task 3 — NGINX Containerisation
- **Base Image:** Pinned `nginx:1.30.6-alpine-slim`.
- **Non-Root Execution:** Runs under UID `101` (`nginx`). Master and workers execute non-root; `nginx.conf` omits the privileged `user nginx;` directive.
- **Port & Endpoints:** Listens on container port 8080.
  - `/`: Serves static page with candidate name, assessment date, and injected `BUILD_SHA`.
  - `/healthz`: Unlogged health endpoint returning HTTP 200 `healthy\n` with `Content-Type: text/plain`.
- **Security Hardening:**
  - `server_tokens off;` prevents leaking NGINX version banners.
  - `X-Content-Type-Options: nosniff` and `X-Frame-Options: SAMEORIGIN` headers enforced.
  - Dotfiles denied (`location ~ /\. { deny all; return 404; }`).
  - Container health check: `wget -qO- http://127.0.0.1:8080/healthz || exit 1`.
- **Image Size:** Docker image size is approximately **20.6 MB** (well below the 60 MB assessment limit).

### Task 4 — GitHub Actions CI/CD
Defined in `.github/workflows/ci.yml`. The workflow is committed, but its GitHub run and GHCR publication are pending the pull request merge:
- **Triggers:** Push to `main` and Pull Requests targeting `main`.
- **Jobs:**
  1. `lint`: Executes ShellCheck on `scripts/` and Hadolint on `app/Dockerfile`.
  2. `build`: Compiles `nginx-app:${{ github.sha }}` with `BUILD_SHA` and `ASSESSMENT_DATE`, exporting the exact image archive `/tmp/nginx-app.tar` as a workflow artifact.
  3. `test`: Downloads `/tmp/nginx-app.tar`, loads it into Docker, launches the container, and verifies `/` and `/healthz` using `./scripts/healthcheck.sh`.
  4. `publish`: Runs **only on push to main**. Downloads the exact tested `/tmp/nginx-app.tar` artifact, loads it, tags it with `${{ github.sha }}` and `latest`, and pushes to GHCR. **Does not rebuild the image.**
- **Least Privilege:** Global workflow permission is `contents: read`. `packages: write` is strictly restricted to the `publish` job.

### Task 5 — Nomad Orchestration & Consul Registration
Defined in `nomad/nginx-app.nomad.hcl`. HCL validation passed with an explicit test image tag. A live Nomad allocation and Consul health check have not yet been verified:
- **Job Configuration:** `type = "service"`, `datacenters = ["dc1"]`, single group `web`, single task `server`.
- **Task Driver:** `docker`, consuming `ghcr.io/${var.ghcr_owner}/nginx-app:${var.image_tag}`.
- **Resources:** CPU: 100 MHz, Memory: 64 MB.
- **Dynamic Port Mapping:**
  ```hcl
  network {
    port "http" {
      to = 8080
    }
  }
  ```
- **Consul Service Registration:**
  Registers service `nginx-app` using allocated port `http`. Configures HTTP health check for `/healthz` at 10s intervals with 2s timeout.
- **Rolling Update & Resilience:**
  `max_parallel = 1`, `min_healthy_time = "10s"`, `healthy_deadline = "2m"`, `auto_revert = true`. Group-level restart (`attempts = 3`, `interval = "5m"`) and reschedule policies.

### Task 6 — Loki, Promtail & Grafana Observability
Defined in `monitoring/docker-compose.yaml`. Compose configuration validation passed, and Loki/Grafana readiness endpoints were checked. End-to-end Promtail ingestion from a Nomad allocation and Grafana Explore results remain to be verified:
- **Loki 2.9.0:** TSDB index with filesystem storage. Bound to `127.0.0.1:3100`.
- **Promtail 2.9.0:**
  - Scrapes container logs via `/var/run/docker.sock`.
  - Filter: `com.hashicorp.nomad.job_id=nginx-app` (targets Nomad-managed containers).
  - Relabeling extracts `job="nginx"`, `service="nginx-app"`, `nomad_alloc_id`, and `container`.
  - Socket access: Runs under unprivileged UID 10001 with supplementary group `986`. Docker socket access is highly privileged, so this is not equivalent to a fully least-privilege isolation boundary.
- **Grafana 10.2.0:** Bound to `127.0.0.1:3000`. Automated datasource provisioning via `monitoring/grafana-datasources.yaml` pre-configures Loki as default datasource.
- **LogQL Queries:**
  - Ingested stream: `{job="nginx"}`
  - Filter 404 access log: `{job="nginx"} |= "404"`

---

## 5. Troubleshooting Log (Genuine Incidents Resolved)

During implementation and testing, four genuine technical defects were identified, diagnosed, and resolved:

### Incident 1: Healthcheck Script Silent Termination Under `set -e`
- **Symptom:** Running `./scripts/healthcheck.sh http://localhost:9999` against a closed port produced no failure diagnostics and terminated prematurely with raw exit code 7.
- **Root Cause:** In `/bin/sh` with `set -e`, `HTTP_CODE=$(curl ...)` triggered an immediate shell exit when `curl` failed to connect (exit 7), completely bypassing the script's error-checking `if` block.
- **Resolution:** Initialized `CURL_EXIT=0` and appended `|| CURL_EXIT=$?` to the subshell command to safely capture curl's exit status. If `CURL_EXIT != 0`, the script explicitly outputs a clear failure message to `stderr` and exits 1.

### Incident 2: Duplicate `Content-Type` Header on `/healthz` Endpoint
- **Symptom:** Querying `/healthz` returned two conflicting `Content-Type` headers (`application/octet-stream` and `text/plain`).
- **Root Cause:** NGINX's `http` block set `default_type application/octet-stream;`. The `/healthz` block contained `add_header Content-Type text/plain;`, causing NGINX to append a second header rather than overriding the default.
- **Resolution:** Replaced `add_header` with `default_type text/plain;` inside `location = /healthz`.

### Incident 3: Promtail Permission Denied Accessing Docker Socket
- **Symptom:** Promtail failed to discover containers when mounting `/var/run/docker.sock`.
- **Root Cause:** Host socket permissions were `0660 root:docker (GID 986)`. Promtail container defaults to non-root UID 10001, lacking permission to read the socket.
- **Resolution:** Added `group_add: ["986"]` to the `promtail` service in `docker-compose.yaml`. This granted supplementary socket group permissions without running Promtail as root.

### Incident 4: Nomad HCL Syntax Placement Error for `reschedule`
- **Symptom:** `nomad job validate` would reject the job specification schema.
- **Root Cause:** The `reschedule` stanza was located at the top-level `job` block. In Nomad HCL syntax, `reschedule` is strictly a `group`-level stanza.
- **Resolution:** Relocated `reschedule` inside `group "web"` directly below `restart`.

---

## 6. Known Limitations & Production Improvements

- **Local Single-Node Architecture:** This project demonstrates a local development lab. A production deployment would use a multi-node Nomad cluster across availability zones with Consul Connect service mesh (mTLS).
- **Socket GID Portability:** Promtail is configured with supplementary group `986`, matching the host's `docker` group. In environments with a different Docker GID, `group_add` should be set to match `stat -c '%g' /var/run/docker.sock`.
- **GHCR Pull Secrets:** In local environments without pre-authenticated Docker credentials, deploying from a private GHCR repository requires configuring Nomad's Docker driver `auth` stanza. Making the package public enables unauthenticated pulls.

---

## 7. Resource Teardown & Cleanup

To stop and remove all local containers, networks, and persistent volumes created during testing:

```bash
# 1. Stop standalone test container
docker stop nginx-app 2>/dev/null || true

# 2. Teardown monitoring stack and remove named volumes
docker compose -f monitoring/docker-compose.yaml down -v

# 3. Remove local test image
docker rmi devops-intern-final:local 2>/dev/null || true
```


## Verification Status at Submission Preparation

- Docker image build, image-size limit, non-root execution, application endpoint, health endpoint, and 404 response: locally verified.
- ShellCheck and shell syntax checks: locally verified.
- Docker Compose configuration: validated.
- Loki and Grafana readiness: locally checked.
- Nomad job HCL: validated with an explicit `image_tag`; no live allocation verified yet.
- GitHub Actions: workflow committed; remote execution and GHCR publication pending.
- Grafana Explore screenshot and end-to-end log ingestion: pending.
