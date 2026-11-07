#!/bin/sh
set -eu

echo "=== System Information ==="
echo "User        : $(whoami) (UID: $(id -u))"
echo "Hostname    : $(hostname)"
echo "Kernel      : $(uname -r)"
echo "Date (ISO)  : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "=== Disk Usage ==="
df -h /
echo ""
echo "=== Memory Usage ==="
free -h 2>/dev/null || vm_stat 2>/dev/null || echo "Memory statistics command unavailable"
echo ""
echo "=== Docker Daemon ==="
if docker info > /dev/null 2>&1; then
  echo "Docker is running"
else
  echo "Docker is NOT running or not installed"
fi
