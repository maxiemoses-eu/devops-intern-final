variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy from GHCR"
}

variable "ghcr_owner" {
  type        = string
  default     = "maxiemoses-eu"
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

  group "web" {
    count = 1
    shutdown_delay = "5s"

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "120s"
      unlimited      = true
    }

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      provider = "consul"
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
