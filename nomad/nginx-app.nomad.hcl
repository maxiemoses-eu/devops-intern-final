variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Docker image tag to deploy from GHCR"
}

variable "ghcr_owner" {
  type        = string
  default     = "YOUR_GITHUB_USERNAME"
  description = "GitHub Container Registry owner (lowercase)"
}

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "default"

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "2m"
    progress_deadline = "5m"
    auto_revert       = true
    canary            = 0
  }

  reschedule {
    delay          = "30s"
    delay_function = "exponential"
    max_delay      = "120s"
    unlimited      = true
  }

  group "web" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "nginx-app"
      port = "http"
      tags = ["web", "nginx", "v${var.image_tag}"]

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "ghcr.io/${var.ghcr_owner}/nginx-app:${var.image_tag}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
