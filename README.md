Markdown
# DevOps Intern Final Assessment
### NGINX Container Pipeline, Nomad Orchestration, and Log Observability

| Property | Value |
| :--- | :--- |
| **Candidate** | Maxie Moses Adams |
| **Submission Date** | 7 November 2026 |
| **Repository** | `maxiemoses-eu/devops-intern-final` |
| **Working Branch** | `feature/core-pipeline` |

---

## 1. Project Overview

This repository contains a static NGINX application and the supporting files for a container build, CI pipeline, orchestration specification, and log-observability stack.

The application is packaged as a small, non-root Docker image. GitHub Actions defines lint, build, test, and image-publication jobs. A HashiCorp Nomad job describes deployment with dynamic port allocation and Consul service registration. Docker Compose runs Loki, Promtail, and Grafana for log collection and exploration.

> **Verification Boundary:** The local Docker image and application runtime have been tested. Local shell checks, Nomad HCL validation, and Docker Compose configuration/readiness checks have also been performed. A successful GitHub-hosted CI run, GHCR publication, live Nomad allocation, Consul health check, and end-to-end Promtail-to-Loki ingestion have not yet been verified. These items are marked as pending below.

---

## 2. Architecture

```mermaid
flowchart TD
    A[Git feature branch] --> B[Pull request to main]
    B --> C[GitHub Actions]
    C --> D[Lint: ShellCheck and Hadolint]
    C --> E[Build image with commit SHA]
    E --> F[Test the built image]
    F --> G[Publish on push to main]
    G --> H[GHCR: SHA tag and latest tag]
    H --> I[Nomad Docker task]
    I --> J[Consul service registration and HTTP health check]
    I --> K[Container logs]
    K --> L[Promtail]
    L --> M[Loki]
    M --> N[Grafana Explore]
The intended deployment reference is the immutable commit-SHA image tag. The latest tag is published for convenience; the Nomad job requires an explicit image_tag and does not default to latest.

3. Repository Layout
Plaintext
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
AGENT.md is a local working-instructions file and is intentionally excluded from the assessment repository.

4. Prerequisites and Tested Environment
The following versions were present during local checks. Nomad and Consul versions are compatibility targets only; no live cluster was used for verification.

Component	Tested Version or Target
Operating System	Ubuntu 24.04 on WSL2
Kernel	Linux 6.18, x86_64
Docker Engine	29.9.3
Docker Compose	v5.7.0
Python	3.10 or later
Shell	/bin/sh (Dash); syntax also checked by Bash
ShellCheck	0.11.0
Nomad	1.7.x / 1.8.x compatibility target; live agent not verified
Consul	1.17.x / 1.18.x compatibility target; live agent not verified
Required local tools: git, Docker Engine with the Compose plugin, curl, POSIX-compatible /bin/sh, and shellcheck. Nomad and Consul agents are required only for the live orchestration stage.

5. Quick Start: Build and Run Locally
Run these commands from a terminal with Docker available. This starts the application locally; it does not deploy it to Nomad.

Bash
# Clone the repository
git clone [https://github.com/maxiemoses-eu/devops-intern-final.git](https://github.com/maxiemoses-eu/devops-intern-final.git)
cd devops-intern-final

# Build with the current Git revision and UTC build date
docker build \
  --build-arg BUILD_SHA="$(git rev-parse HEAD)" \
  --build-arg ASSESSMENT_DATE="$(date -u +%Y-%m-%d)" \
  -t devops-intern-final:local \
  -f app/Dockerfile app/

# Run the application
docker run -d --rm --name nginx-app \
  -p 8080:8080 devops-intern-final:local

# Verify the health endpoint and application page
./scripts/healthcheck.sh http://localhost:8080/healthz
curl -i http://localhost:8080/

# Start Loki, Promtail, and Grafana
docker compose -f monitoring/docker-compose.yaml up -d

# Check service readiness
curl -fsS [http://127.0.0.1:3100/ready](http://127.0.0.1:3100/ready)
curl -fsS [http://127.0.0.1:3000/api/health](http://127.0.0.1:3000/api/health)
The monitoring services can run independently. Meaningful Nomad log collection requires a Nomad-managed NGINX container with matching Docker labels and a working Promtail discovery/ingestion path; that end-to-end path remains unverified.

6. Implementation and Verification
6.1 Source Control and Git Workflow
Work was developed incrementally on feature/core-pipeline using conventional commit prefixes, including feat:, fix:, ci:, and docs:.

The intended release sequence is:

Develop and commit changes on the feature branch.

Push the branch to GitHub.

Open and review a pull request targeting main.

Merge after reviewing the changes and CI results.

Create and push the v1.0.0 tag on the final merged commit.

Current status: The feature branch and incremental commit history have been pushed. Pull-request review/merge and the v1.0.0 release tag remain pending.

6.2 Linux Shell Scripts
Two executable scripts are provided in scripts/.

scripts/sysinfo.sh reports:

Current user and UID.

Hostname and kernel release.

UTC date in ISO-8601 format.

Root filesystem usage.

Memory information.

Docker daemon availability.

The script uses #!/bin/sh and set -eu. The assessment brief also mentions set -euo pipefail, but pipefail is not a POSIX shell option and is unsupported by shells such as Ubuntu's Dash. This implementation keeps the script POSIX-shell compatible rather than claiming POSIX compatibility while relying on a Bash-specific option.

scripts/healthcheck.sh accepts a URL as its first argument and defaults to http://localhost:8080. It uses curl with a 3-second connection timeout and a 5-second total timeout. It exits successfully only for HTTP 200; connection failures and other HTTP statuses produce a diagnostic and a non-zero exit code.

Observed Local Health-Check Results
Command	Result
./scripts/healthcheck.sh http://localhost:8080	HTTP 200; exit 0
./scripts/healthcheck.sh http://localhost:8080/nonexistent	HTTP 404; exit 1
./scripts/healthcheck.sh http://localhost:9999	Connection failure; exit 1
Both scripts passed local ShellCheck and shell syntax checks. Their executable Git file mode was verified as 100755.

6.3 NGINX Containerisation
The application uses the pinned base image nginx:1.30.6-alpine-slim.

Implementation details:

NGINX runs as the non-root nginx user (UID 101).

The application listens on container port 8080.

EXPOSE 8080 documents the container port.

The Dockerfile defines a health check against /healthz.

BUILD_SHA and ASSESSMENT_DATE are injected at build time and rendered on the application page.

server_tokens off suppresses the NGINX version in response headers.

Security headers include X-Content-Type-Options: nosniff and X-Frame-Options: SAMEORIGIN.

Dotfile requests are denied.

NGINX access and error logs are directed to container output for collection.

Build and Run
Bash
docker build \
  --build-arg BUILD_SHA="$(git rev-parse HEAD)" \
  --build-arg ASSESSMENT_DATE="$(date -u +%Y-%m-%d)" \
  -t devops-intern-final:local \
  -f app/Dockerfile app/

docker run -d --rm --name nginx-app \
  -p 8080:8080 devops-intern-final:local

curl -i http://localhost:8080/
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/nonexistent
docker inspect nginx-app --format '{{.Config.User}}'
docker inspect nginx-app --format '{{.State.Health.Status}}'
Observed local results:

/ returned HTTP 200.

/healthz returned HTTP 200 with body healthy.

/nonexistent returned HTTP 404.

The container ran as nginx and Docker reported its health state as healthy.

The image measured approximately 20.6 MB, below the assessment limit of 60 MB.

6.4 GitHub Actions CI/CD
The workflow is .github/workflows/ci.yml. It is configured for pushes to main and pull requests targeting main and contains four jobs:

Job	Responsibility
lint	Runs ShellCheck against the scripts and Hadolint against the Dockerfile.
build	Builds the image with the commit SHA and assessment date, checks the image-size limit, and uploads the image as an artifact.
test	Downloads and loads that same image artifact, starts the container, checks readiness, tests / and /healthz, and verifies a 404 response.
publish	Runs only on pushes to main; downloads the tested image artifact and publishes SHA and latest tags to GHCR.
The publishing job alone receives packages: write. The workflow uses GITHUB_TOKEN; pull-request events do not publish images. The publish job loads the image produced by the build job rather than rebuilding a different image.

Current status: The workflow file is committed and its YAML syntax was checked locally. A GitHub-hosted pull-request run, a successful push-to-main run, and the resulting GHCR package/tags remain pending verification. The badge at the top of this README reflects the actual GitHub Actions workflow status.

6.5 Nomad Orchestration and Consul Registration
The job specification is nomad/nginx-app.nomad.hcl. It defines:

A service job with one group (web) and one task (server).

The Docker task driver.

A GHCR image reference parameterised by ghcr_owner and image_tag.

CPU allocation of 100 MHz and memory allocation of 64 MB.

A dynamic host port named http, mapped to container port 8080.

Consul service registration for nginx-app.

An HTTP check against /healthz every 10 seconds, with a 2-second timeout.

Rolling-update settings: max_parallel = 1, min_healthy_time = "10s", healthy_deadline = "2m", and auto_revert = true.

Group-level restart and reschedule policies.

The image tag must be supplied explicitly; the job does not silently default to latest.

Validate, Plan, and Run Against an Authorised Nomad/Consul Lab
Bash
nomad job validate \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl

nomad job plan \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl

nomad job run \
  -var="image_tag=<published-commit-sha>" \
  nomad/nginx-app.nomad.hcl

nomad job status nginx-app
nomad alloc status <allocation-id>
consul health service nginx-app
Replace <published-commit-sha> with the actual image tag published to GHCR. The Nomad client must be able to pull that image. For a private GHCR package, configure registry authentication through the Nomad Docker driver using a secure credential mechanism; do not put credentials in the job file or commit them.

Current status: Nomad HCL validation succeeded using an explicit test image tag. Validation was performed without a connected Nomad agent; it does not prove driver connectivity, image pulling, allocation health, or Consul registration. A live allocation and healthy Consul check have not yet been verified.

6.6 Loki, Promtail, and Grafana
The local observability stack is defined in monitoring/docker-compose.yaml.

Component	Version	Purpose
Loki	2.9.0	Log storage and query API
Promtail	2.9.0	Docker service discovery and log shipping
Grafana	10.2.0	Log exploration through a provisioned Loki data source
The services bind to loopback addresses: Loki 127.0.0.1:3100, Promtail 127.0.0.1:9080, and Grafana 127.0.0.1:3000. Loki uses a TSDB index and filesystem-backed storage. Grafana's Loki data source is provisioned from monitoring/grafana-datasources.yaml.

Promtail is configured to discover Docker containers carrying the Nomad job label com.hashicorp.nomad.job_id=nginx-app. It derives labels for the container, Nomad allocation ID, service, and log job.

Validate and Start the Stack
Bash
docker compose -f monitoring/docker-compose.yaml config -q
docker compose -f monitoring/docker-compose.yaml up -d
docker compose -f monitoring/docker-compose.yaml ps
curl -fsS [http://127.0.0.1:3100/ready](http://127.0.0.1:3100/ready)
curl -fsS [http://127.0.0.1:3000/api/health](http://127.0.0.1:3000/api/health)
Example LogQL Queries
Code snippet
# Select the NGINX stream
{job="nginx"}

# Find access-log entries containing a 404 status
{job="nginx"} |= "404"

# Parse access logs and isolate non-200 responses
{job="nginx"}
| pattern `<ip> - - [<_>] "<method> <path> HTTP/<_>" <status> <_>`
| __error__=""
| status != "200"
Security Consideration: Promtail runs as an unprivileged container user, but it is granted supplementary group access to the host Docker socket so it can discover containers. Access to the Docker socket is highly privileged and can provide control over the Docker daemon. This is a local-lab trade-off, not a strong security boundary.

Current status: Docker Compose configuration validation succeeded. Loki's readiness endpoint and Grafana's health endpoint responded successfully. Actual Promtail target discovery, log shipping from a Nomad allocation, successful LogQL results, and a Grafana Explore screenshot have not yet been verified. No screenshot is presented as evidence until it is captured from a real working Explore session. See monitoring/loki_setup.md for detailed setup notes.

7. Troubleshooting and Engineering Decisions
The following issues were encountered during implementation and corrected.

7.1 Health-check script exited before printing a diagnostic
Symptom: A request to a closed port caused the script to exit with curl's status before displaying the intended failure message.

Cause: Under set -e, the failing command substitution terminated the shell before the subsequent error handling ran.

Resolution: Capture the curl exit status with an explicit || branch, then report the connection failure and return a controlled non-zero status.

7.2 Duplicate Content-Type headers on /healthz
Symptom: The health endpoint returned conflicting Content-Type headers.

Cause: The NGINX HTTP-level default type and an add_header Content-Type directive both contributed a header.

Resolution: Use default_type text/plain within the exact /healthz location instead of adding a second Content-Type header.

7.3 Promtail could not access the Docker socket
Symptom: Promtail could not discover Docker containers through the mounted socket.

Cause: The host socket was owned by root:docker with mode 0660; the Promtail process initially lacked the socket group's permissions.

Resolution: Add the host Docker socket's group ID as a supplementary group for the Promtail service. The configured GID (986) is specific to the tested host and must be checked on other systems.

7.4 Nomad reschedule stanza was at the wrong level
Symptom: The Nomad job specification failed structural validation.

Cause: The reschedule stanza was placed in the job block instead of the group block.

Resolution: Move reschedule into group "web", alongside the group-level restart policy.

8. Known Limitations and Security Considerations
Local lab, not production: This is a single-machine development setup. It does not demonstrate high availability, multi-node scheduling, production incident response, or a production service mesh.

Nomad and Consul runtime evidence is outstanding: The job specification validates, but a healthy allocation and Consul check have not been demonstrated.

CI and registry evidence is outstanding: The GitHub Actions workflow has not yet been verified by a remote run, and GHCR publication is pending.

Log-ingestion evidence is outstanding: Loki and Grafana readiness were checked, but the complete Nomad-to-Promtail-to-Loki path and Grafana Explore query results remain unverified.

Docker socket privilege: Mounting /var/run/docker.sock gives Promtail access to a highly privileged host interface. A production design should use a deliberately scoped log-collection approach that avoids unnecessary Docker API access.

Socket group portability: The supplementary group ID (986) matches the test host. Check the actual socket group on another host before starting the stack.

GHCR authentication: Nomad clients need permission to pull the selected image. A private package requires secure registry authentication; do not store credentials in Git or the Nomad job specification.

Promtail lifecycle: Promtail is retained because it is explicitly required by this assessment. Its lifecycle and support status should be considered before adopting it for a new long-lived production platform.

Shell specification conflict: The scripts use POSIX /bin/sh with set -eu; they do not use the non-POSIX pipefail option.

9. Cleanup
Run from the repository root. These commands stop the named local application container and this repository's Compose stack.

Bash
# Stop the standalone application container if it is running
docker stop nginx-app 2>/dev/null || true

# Stop the monitoring stack and remove its named persistent volumes
docker compose -f monitoring/docker-compose.yaml down -v

# Remove the local assessment image
docker rmi devops-intern-final:local 2>/dev/null || true
⚠️ Warning: docker compose ... down -v deletes the Compose-managed Loki and Grafana data volumes. Do not use it if you need to retain locally collected logs or Grafana state.

10. Verification Summary
Area	Evidence and Current Status
Git workflow	Feature branch and incremental commits pushed; pull-request review/merge and v1.0.0 tag pending.
Shell scripts	ShellCheck and shell syntax checks passed; executable Git modes verified.
Docker image	Build and runtime checks passed; non-root user verified; image measured at approximately 20.6 MB.
Application endpoints	/ and /healthz returned HTTP 200; missing route returned HTTP 404.
GitHub Actions	Workflow committed and YAML syntax checked locally; remote CI run pending.
GHCR	Publication and SHA/latest tags pending a successful push to main.
Nomad	Job specification validation passed; no live allocation verified.
Consul	Service registration and health status not yet verified.
Docker Compose	Configuration validation passed.
Loki and Grafana	Readiness/health endpoints checked successfully.
Promtail	End-to-end target discovery and log ingestion not yet verified.
Grafana Explore	Real query result and screenshot pending.
11. Submission Checklist
Before treating the assessment as fully complete:

[x] Push feature/core-pipeline to the public GitHub repository.

[ ] Open and self-review a pull request targeting main.

[ ] Obtain a successful pull-request CI run and resolve any failures.

[ ] Merge the pull request.

[ ] Verify the push-to-main workflow and both GHCR image tags.

[ ] Deploy the published SHA-tagged image to an authorised Nomad/Consul lab.

[ ] Verify the Nomad allocation and Consul health check.

[ ] Verify Promtail discovery and actual log ingestion into Loki.

[ ] Run a LogQL query in Grafana Explore and save a genuine screenshot under docs/screenshots/.

[ ] Create and push v1.0.0 on the final submitted commit.

[ ] Complete the required HR progress form personally, using accurate login/logout times and the assigned-by information supplied for the assessment.

The implementation and verification statements in this README reflect the checks performed so far. Any item marked pending must be verified before it is represented as completed.