# Loki Stack Setup

## How I Started the Stack

\`\`\`bash
cd monitoring
docker compose up -d
docker compose ps   # verify all three services are healthy
\`\`\`

## Label Set Applied

Promtail attaches these labels to every log line:
- \`job=nginx\` — fixed label identifying the workload
- \`container\` — from Docker metadata (\`__meta_docker_container_name\`)
- \`service\` — from Docker Compose service label

## LogQL Queries Run

### All NGINX access logs

    {job="nginx"}

### Filter for non-200 responses (after requesting /missing-path)

    {job="nginx"} |= "404"

### Filter errors only

    {job="nginx"} | pattern \`<ip> - - [<_>] "<method> <path> HTTP/<_>" <status> <_>\` | status != "200"

## Results

Logs appeared in Grafana Explore within 10 seconds of the container starting.
The 404 filter correctly isolated the access log line for a deliberately missing path.

## Problems Encountered

1. **Promtail couldn't connect to Docker socket** — fixed by ensuring the socket path in the config matched the host (\`unix:///var/run/docker.sock\`) and that the user running Docker Compose had socket access.
2. **Loki returned "entry out of order" errors** — resolved by setting \`reject_old_samples: true\` and ensuring system clock was correct.
3. **Grafana showed no data source** — manually added Loki as a data source at \`http://loki:3100\` in Grafana UI; the services share the \`monitoring\` network so the hostname resolves.
