# Relays GitHub webhooks from a smee.io channel to a target inside the cluster (ADR-0015). The
# cluster only makes an outbound connection to smee.io, so nothing here is exposed to the internet.
# smee cannot preserve the webhook signature, so the target must not require one.
resource "kubernetes_secret_v1" "smee" {
  metadata {
    name      = "smee-channel"
    namespace = var.namespace
  }

  data = {
    url = var.smee_url
  }
}

resource "kubernetes_deployment_v1" "smee_client" {
  metadata {
    name      = "smee-client"
    namespace = var.namespace
    labels    = { app = "smee-client" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "smee-client" }
    }

    template {
      metadata {
        labels = { app = "smee-client" }
      }

      spec {
        container {
          name  = "smee-client"
          image = var.image

          # smee-client is installed from npm at start, pinned to an exact version.
          command = ["sh", "-c"]
          args    = ["exec npx --yes smee-client@${var.smee_client_version} --url \"$SMEE_URL\" --target \"$TARGET_URL\""]

          env {
            name = "SMEE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.smee.metadata[0].name
                key  = "url"
              }
            }
          }
          env {
            name  = "TARGET_URL"
            value = var.target_url
          }
          # The root filesystem is read-only; npm needs somewhere to write.
          env {
            name  = "HOME"
            value = "/tmp"
          }
          env {
            name  = "npm_config_cache"
            value = "/tmp/npm"
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            requests = { cpu = "20m", memory = "96Mi" }
            limits   = { memory = "256Mi" }
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}
