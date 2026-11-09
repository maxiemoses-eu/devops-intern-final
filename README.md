# DevOps Intern Final Assessment

## NGINX Container Pipeline, Nomad Orchestration and Observability

| Project detail   | Value                               |
| ---------------- | ----------------------------------- |
| Candidate        | Maxie Moses Adams                   |
| Submission date  | 7 November 2026                     |
| Repository       | maxiemoses-eu/devops-intern-final   |
| Working branch   | feature/core-pipeline               |

---

## 1. Project overview

This repository contains a containerised static NGINX application and the supporting files for a CI/CD, orchestration and log-observability workflow.

The application is built as a small, non-root Docker image. GitHub Actions defines linting, image build, application tests and publication to GitHub Container Registry (GHCR). A HashiCorp Nomad job specification describes deployment with dynamic port allocation and Consul service registration. A local Docker Compose stack provides Loki, Promtail and Grafana for log collection and exploration.

> **Verification boundary:** the application image and its local runtime behaviour have been tested. The CI workflow, live Nomad allocation, Consul health status, and end-to-end Promtail-to-Loki log ingestion have not yet been verified in a remote or live Nomad environment. Those stages are identified as pending rather than reported as completed.

---

## 2. Architecture

```
                     Git repository
                 feature branch -> PR -> main
                            |
                            v
                    GitHub Actions CI
              +-------------+-------------+
              |             |             |
            Lint          Build          Test
        ShellCheck +    Docker image   Exact image
          Hadolint      with BUILD_SHA  from build
                                          |
                                          v
                                Push to main only
                                          |
                                          v
                              GitHub Container Registry
                              SHA tag + latest convenience tag
                                          |
                                          v
                                  HashiCorp Nomad
                                  Docker task driver
                                          |
                          +---------------+---------------+
                          |                               |
                          v                               v
                    HashiCorp Consul               Container stdout
                    Service registration                 |
                    HTTP /healthz check                   v
                                                      Promtail
                                                Docker service discovery
                                                          |
                                                          v
                                                        Loki
                                                          |
                                                          v
                                                   Grafana Explore
```

The intended deployment flow uses an immutable commit-SHA image tag. The `latest` tag is published as a convenience tag and is **not** the deployment reference required by the Nomad job.

---

## 3. Repository layout

```
devops-intern-final/
├── .github/
│   └── workflows/
│       └── ci.yml
├── app/
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
├── docs/
│   └── screenshots/
├── monitoring/
│   ├── docker-compose.yaml
│   ├── grafana-datasources.yaml
│   ├── loki-config.yaml
│   ├── loki_setup.md
│   └── promtail-config.yaml
├── nomad/
│   └── nginx-app.nomad.hcl
├── scripts/
│   ├── healthcheck.sh
│   └── sysinfo.sh
├── .gitignore
└── README.md
```

## 4. Prerequisites and tested environment

### Tested environment

| Component      | Tested version or compatibility target              |
| -------------- | --------------------------------------------------- |
| OS             | Ubuntu 24.04 on WSL2                                |
| Kernel         | Linux 6.18, x86_64                                  |
| Docker Engine  | 29.9.3                                              |
| Docker Compose | v5.7.0                                              |
| Python         | 3.10 or later                                       |
| Shell          | `/bin/sh` (Dash), syntax also checked by Bash       |
| ShellCheck     | 0.11.0                                              |
| Nomad          | 1.7.x / 1.8.x compatibility target; not live-verified |
| Consul         | 1.17.x / 1.18.x compatibility target; not live-verified |

### Required local tools

- Git
- Docker Engine with Docker Compose
- `curl`
- POSIX-compatible `/bin/sh`
- ShellCheck for shell-script linting

> Nomad and Consul agents are required only for the live orchestration stage. The version ranges above are compatibility targets, not evidence that a Nomad or Consul cluster was deployed.

---

## 5. Quick start: build and run locally

The following steps build and run the application and start the local monitoring services. They do **not** deploy the application to Nomad.

```bash
# 1. Clone the repository
git clone https://github.com/maxiemoses-eu/devops-intern-final.git
cd devops-intern-final

# 2. Build the application image with the current Git revision and UTC date
docker build \
  --build-arg BUILD_SHA="$(git rev-parse HEAD)" \
  --build-arg ASSESSMENT_DATE="$(date -u +%Y-%m-%d)" \
  -t devops-intern-final:local \
  -f app/Dockerfile app/

# 3. Start the application
docker run -d --rm --name nginx-app \
  -p 8080:8080 devops-intern-final:local

# 4. Check the health endpoint
./scripts/healthcheck.sh http://localhost:8080/healthz

# 5. Inspect the application page
curl -i http://localhost:8080/

# 6. Start Loki, Promtail and Grafana
docker compose -f monitoring/docker-compose.yaml up -d

# 7. Check Loki and Grafana readiness
curl -fsS http://127.0.0.1:3100/ready
curl -fsS http://127.0.0.1:3000/api/health
```

> The monitoring services can be started independently, but meaningful Nomad log collection requires a matching Nomad-managed NGINX container and a working Promtail discovery/ingestion path. That end-to-end path remains unverified.

---

## 6. Implementation and verification

### Task 1 — Source control and Git workflow

The project was developed incrementally on the `feature/core-pipeline` branch using conventional commit prefixes: `feat:`, `fix:`, `ci:` and `docs:`.

**Intended release workflow:**

1. Develop and commit changes on the feature branch.
2. Push the branch to GitHub.
3. Open and review a pull request targeting `main`.
4. Merge the pull request after reviewing the changes and CI results.
5. Create the `v1.0.0` tag on the final merged state.

> **Status:** the feature branch and incremental commit history exist. Pull request creation/merge and the `v1.0.0` release tag are pending final GitHub verification.

---

### Task 2 — Linux shell scripts

Two executable scripts are provided in `scripts/`.

#### `scripts/sysinfo.sh`

Reports:

- Current user and UID
- Hostname and kernel release
- UTC date in ISO-8601 format
- Root filesystem usage
- Memory information
- Docker daemon availability

The script uses `#!/bin/sh` and `set -eu`. The assessment brief also mentions `set -euo pipefail`, but `pipefail` is not a POSIX shell option and is unsupported by shells such as Ubuntu's Dash. The implementation retains a POSIX shell rather than claiming POSIX compatibility while depending on a Bash-specific option.

**Sample output (captured during local testing):**

```
=== System Information ===
User        : maxie (UID: 1000)
Hostname    : DESKTOP-0S7PFBM
Kernel      : 6.18.54.1-microsoft-standard-WSL2
Date (ISO)  : 2026-11-06T17:25:43Z

=== Disk Usage ===
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdd       1007G  7.6G  949G   1% /

=== Memory Usage ===
                  total   used   free  shared  buff/cache  available
Mem:              5.7Gi  2.4Gi   92Mi    30Mi      3.4Gi       3.3Gi
Swap:             2.0Gi  3.4Mi  2.0Gi

=== Docker Daemon ===
Docker is running
```

> System values are environment-specific and will differ on another host.

#### `scripts/healthcheck.sh`

Accepts a URL as its first argument and defaults to `http://localhost:8080`. It uses `curl` with a 3-second connection timeout and a 5-second total timeout. It exits successfully only when the HTTP response is 200; connection failures and other HTTP statuses produce a diagnostic and a non-zero exit code.

**Observed local checks:**

| Test                                              | Result                    |
| ------------------------------------------------- | ------------------------- |
| `./scripts/healthcheck.sh http://localhost:8080`  | HTTP 200; exit 0          |
| `./scripts/healthcheck.sh http://localhost:8080/nonexistent` | HTTP 404; exit 1 |
| `./scripts/healthcheck.sh http://localhost:9999`  | Connection failure; exit 1 |

Both scripts passed the local ShellCheck and shell syntax checks. Their executable Git file mode was verified as `100755`.

---

### Task 3 — NGINX containerisation

The application is built from the pinned base image `nginx:1.30.6-alpine-slim`.

**Key implementation details:**

- NGINX runs as the non-root `nginx` user (UID 101).
- The application listens on container port `8080`.
- `EXPOSE 8080` documents the container port.
- The Dockerfile defines a health check against `/healthz`.
- `BUILD_SHA` and `ASSESSMENT_DATE` are injected during the image build and rendered in the application page.
- `server_tokens off` suppresses the NGINX version in response headers.
- Security headers include `X-Content-Type-Options: nosniff` and `X-Frame-Options: SAMEORIGIN`.
- Dotfile requests are denied.
- NGINX access and error logs are directed to container output for log collection.

**Build:**

```bash
docker build \
  --build-arg BUILD_SHA="$(git rev-parse HEAD)" \
  --build-arg ASSESSMENT_DATE="$(date -u +%Y-%m-%d)" \
  -t devops-intern-final:local \
  -f app/Dockerfile app/
```

**Run and verify:**

```bash
docker run -d --rm --name nginx-app \
  -p 8080:8080 devops-intern-final:local

curl -i http://localhost:8080/
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/nonexistent

docker inspect nginx-app --format '{{.Config.User}}'
docker inspect nginx-app --format '{{.State.Health.Status}}'
```

**Observed checks confirmed:**

- `/` returned HTTP 200.
- `/healthz` returned HTTP 200 with the body `healthy`.
- `/nonexistent` returned HTTP 404.
- The container ran as `nginx`.
- Docker reported the container health state as `healthy`.

The measured Docker image size was approximately **20.6 MB**, below the assessment limit of 60 MB.

---

### Task 4 — GitHub Actions CI/CD

The workflow is defined in `.github/workflows/ci.yml`.

**Triggers:**

- Pushes to `main`
- Pull requests targeting `main`

**Jobs:**

| Job     | Responsibility |
| ------- | -------------- |
| `lint`  | Runs ShellCheck against the scripts and Hadolint against the Dockerfile. |
| `build` | Builds the image with the commit SHA and assessment date, checks the image-size limit, and uploads the image as an artifact. |
| `test`  | Downloads and loads that same image artifact, starts the container, checks readiness, tests `/` and `/healthz`, and verifies a 404 response. |
| `publish` | Runs only on pushes to `main`; downloads the tested image artifact and publishes SHA and `latest` tags to GHCR. |

The publishing job alone receives `packages: write`. The workflow uses `GITHUB_TOKEN`; pull-request events do not publish images. The `publish` job loads the image produced by the `build` job rather than rebuilding a different image.

> **Status:** the workflow file is committed and has been checked locally for YAML syntax. A GitHub-hosted pull-request run, a successful push-to-main run, and the resulting GHCR package/tags are still pending verification. The badge at the top links to the actual workflow and will reflect its GitHub status.

---

### Task 5 — Nomad orchestration and Consul registration

The job specification is `nomad/nginx-app.nomad.hcl`.

**It defines:**

- A `service` job with one group (`web`) and one task (`server`).
- The Docker task driver.
- A GHCR image reference parameterised by `ghcr_owner` and `image_tag`.
- CPU allocation of 100 MHz and memory allocation of 64 MB.
- A dynamic host port named `http`, mapped to container port 8080.
- Consul service registration for `nginx-app`.
- An HTTP check against `/healthz`, every 10 seconds, with a 2-second timeout.
- Rolling-update settings: `max_parallel = 1`, `min_healthy_time = "10s"`, `healthy_deadline = "2m"` and `auto_revert = true`.
- Group-level restart and reschedule policies.

The image tag is required explicitly; the job does not silently default to `latest`.

**Validate the job specification:**

```bash
nomad job validate \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl
```

**Plan and run against an authorised Nomad/Consul lab:**

```bash
nomad job plan \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl

nomad job run \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl

nomad job status nginx-app
nomad alloc status <allocation-id>
consul health service nginx-app
```

> Replace `<published-commit-sha>` with the actual image tag published to GHCR. The Nomad client must be able to pull that image. For a private GHCR package, configure registry authentication through the Nomad Docker driver using a secure credential mechanism; do not place credentials in the job file or commit them.

> **Status:** Nomad HCL validation succeeded using an explicit test image tag. Validation was performed without a connected Nomad agent, so it does not prove driver connectivity, image pulling, allocation health or Consul registration. A live allocation and healthy Consul check have not yet been verified.

---

### Task 6 — Loki, Promtail and Grafana

The local observability stack is defined in `monitoring/docker-compose.yaml`.

| Component | Version | Purpose |
| --------- | ------- | ------- |
| Loki      | 2.9.0   | Log storage and query API |
| Promtail  | 2.9.0   | Docker service discovery and log shipping |
| Grafana   | 10.2.0  | Log exploration through a provisioned Loki data source |

**Service bindings (loopback only):**

- Loki: `127.0.0.1:3100`
- Promtail: `127.0.0.1:9080`
- Grafana: `127.0.0.1:3000`

Loki uses a TSDB index and filesystem-backed storage. Grafana's Loki data source is provisioned from `monitoring/grafana-datasources.yaml`.

Promtail is configured to discover Docker containers carrying the Nomad job label `com.hashicorp.nomad.job_id=nginx-app`. It derives labels for the container, Nomad allocation ID, service and log job.

**Validate and start the stack:**

```bash
docker compose -f monitoring/docker-compose.yaml config -q
docker compose -f monitoring/docker-compose.yaml up -d
docker compose -f monitoring/docker-compose.yaml ps

curl -fsS http://127.0.0.1:3100/ready
curl -fsS http://127.0.0.1:3000/api/health
```

**Example LogQL queries:**

Select the NGINX stream:

```logql
{job="nginx"}
```

Filter access-log entries containing a 404 status:

```logql
{job="nginx"} |= "404"
```

Isolate non-200 access responses using a structured pattern:

```logql
{job="nginx"}
| pattern `<ip> - - [<_>] "<method> <path> HTTP/<_>" <status> <_>`
| __error__=""
| status != "200"
```

> **Security note:** Promtail runs as an unprivileged container user, but it is granted supplementary group access to the host Docker socket so it can discover containers. Access to the Docker socket is highly privileged and can provide control over the Docker daemon. This configuration is a local-lab trade-off, not a strong security boundary.

> **Status:** Docker Compose configuration validation succeeded. Loki's readiness endpoint and Grafana's health endpoint responded successfully. Actual Promtail target discovery, log shipping from a Nomad allocation, successful LogQL results and a Grafana Explore screenshot have not yet been verified. No screenshot is presented as evidence until it is captured from a real working Explore session.

For detailed configuration and setup notes, see [`monitoring/loki_setup.md`](monitoring/loki_setup.md).

---

## 7. Troubleshooting and engineering decisions

### 7.1 Health-check script exited before printing a diagnostic

**Symptom:** a request to a closed port caused the script to exit with `curl`'s status before displaying the intended failure message.

**Cause:** under `set -e`, the failing command substitution terminated the shell before the subsequent error handling ran.

**Resolution:** capture the `curl` exit status with an explicit `||` branch, then report the connection failure and return a controlled non-zero status.

### 7.2 Duplicate Content-Type headers on `/healthz`

**Symptom:** the health endpoint returned conflicting `Content-Type` headers.

**Cause:** the NGINX HTTP-level `default_type` and an `add_header Content-Type` directive both contributed a header.

**Resolution:** use `default_type text/plain` within the exact `/healthz` location instead of adding a second `Content-Type` header.

### 7.3 Promtail could not access the Docker socket

**Symptom:** Promtail could not discover Docker containers through the mounted socket.

**Cause:** the host socket was owned by `root:docker` with mode `0660`; the Promtail process did not initially have the socket's group permissions.

**Resolution:** add the host Docker socket's group ID as a supplementary group for the Promtail service. The configured GID (`986`) is specific to the tested host and must be checked on other systems.

### 7.4 Nomad `reschedule` stanza was at the wrong level

**Symptom:** the Nomad job specification failed structural validation.

**Cause:** the `reschedule` stanza was placed in the `job` block instead of the `group` block.

**Resolution:** move `reschedule` into `group "web"`, alongside the group-level `restart` policy.

---

## 8. Known limitations and security considerations

- **Local lab, not production:** this work is a single-machine development setup. It does not demonstrate high availability, multi-node scheduling, production incident response or a production service mesh.
- **Nomad and Consul runtime evidence is outstanding:** the job specification validates, but a healthy allocation and Consul check have not been demonstrated.
- **CI and registry evidence is outstanding:** the GitHub Actions workflow has not yet been verified by a remote run, and GHCR publication is pending.
- **Log-ingestion evidence is outstanding:** Loki and Grafana readiness were checked, but the complete Nomad-to-Promtail-to-Loki path and Grafana Explore query results remain unverified.
- **Docker socket privilege:** mounting `/var/run/docker.sock` gives Promtail access to a highly privileged host interface. A production design should use a deliberately scoped log-collection approach that avoids granting unnecessary Docker API access.
- **Socket group portability:** the configured supplementary group ID (`986`) matches the test host. Check the actual socket group on another host before starting the stack.
- **GHCR authentication:** Nomad clients need permission to pull the selected image. A private package requires secure registry authentication; do not store credentials in Git or the Nomad job specification.
- **Promtail lifecycle:** Promtail is retained because it is explicitly required by this assessment. Its lifecycle and support status should be considered before adopting it for a new long-lived production platform.
- **Shell specification conflict:** the scripts use POSIX `/bin/sh` with `set -eu`; they do not use the non-POSIX `pipefail` option.

---

## 9. Cleanup

Run these commands from the repository root. They stop only the named local application container and this repository's Compose stack.

```bash
# Stop the standalone application container if it is running
docker stop nginx-app 2>/dev/null || true

# Stop the monitoring stack and remove its named persistent volumes
docker compose -f monitoring/docker-compose.yaml down -v

# Remove the local assessment image
docker rmi devops-intern-final:local 2>/dev/null || true
```

> `down -v` deletes the Compose-managed Loki and Grafana data volumes. Do not use it if you need to retain locally collected logs or Grafana state.

---

## 10. Verification summary

| Area               | Evidence and current status |
| ------------------ | --------------------------- |
| Git workflow       | Feature branch and incremental commits exist; PR merge and `v1.0.0` tag pending. |
| Shell scripts      | ShellCheck and shell syntax checks passed; executable Git modes verified. |
| Docker image       | Build and runtime checks passed; non-root user verified; image measured at ~20.6 MB. |
| Application endpoints | `/` and `/healthz` returned HTTP 200; missing route returned HTTP 404. |
| GitHub Actions     | Workflow committed and YAML syntax checked locally; remote CI run pending. |
| GHCR               | Publication and SHA/`latest` tags pending a successful push to `main`. |
| Nomad              | Job specification validation passed; no live allocation verified. |
| Consul             | Service registration and health status not yet verified. |
| Compose            | Configuration validation passed. |
| Loki and Grafana   | Readiness/health endpoints checked successfully. |
| Promtail           | End-to-end target discovery and log ingestion not yet verified. |
| Grafana Explore    | Real query result and screenshot pending. |

---

## 11. Submission checklist

Before treating the assessment as fully complete:

- [ ] Push `feature/core-pipeline` to the public GitHub repository.
- [ ] Open and self-review a pull request targeting `main`.
- [ ] Obtain a successful pull-request CI run and resolve any failures.
- [ ] Merge the pull request.
- [ ] Verify the push-to-main workflow and both GHCR image tags.
- [ ] Deploy the published SHA-tagged image to an authorised Nomad/Consul lab.
- [ ] Verify the Nomad allocation and Consul health check.
- [ ] Verify Promtail discovery and actual log ingestion into Loki.
- [ ] Run a LogQL query in Grafana Explore and save a genuine screenshot under `docs/screenshots/`.
- [ ] Create and push `v1.0.0` on the final submitted commit.
- [ ] Complete the required HR progress form personally, using accurate login/logout times and the assigned-by information supplied for the assessment.

> The implementation and verification statements in this README reflect the local checks performed so far. Any item marked pending must be verified before it is represented as completed.