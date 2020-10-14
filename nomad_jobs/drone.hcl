job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  constraint {
    attribute = "${meta.vmck_ci}"
    operator = "is_set"
  }

  group "drone" {
    task "drone-vault" {
        
      constraint {
        attribute = "${meta.vmck_worker}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        network_mode = "host"
        image = "drone/vault"
        args = [
            "--publish", "3000:3000",
            "--restart", "always",
            "--name", "secrets",
        ]
        privileged = "true"
      }
      env {
        # Docker machine information
        DRONE_LOGS_TRACE = "true"
        DRONE_TRACE = "true"
        DRONE_AGENTS_DISABLED = "true"
        DRONE_SERVER_HOST = "frisbee.grid.pub.ro"
        VAULT_ADDR = "http://10.42.1.1:8200"
        DRONE_SERVER_HOST = "frisbee.grid.pub.ro"
        VAULT_TOKEN = ""
      }
      template {
        data = <<-EOF
          {{- with secret "kv/drone/vault" }}
           DRONE_SECRET = {{.Data.secret_plugin | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone-vault.env"
        env = true
      }
      resources {
        memory = 250
        cpu = 150
        network {
          mbits = 1
          port "http" {
            static = 9998
          }
        }
      }
      service {
        name = "drone-vault"
        port = "http"
        tags = [
          "ingress.enable=true",
          "ingress.frontend.rule=Host:frisbee.grid.pub.ro",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "20s"
        }
      }
    }

    task "drone" {
      constraint {
        attribute = "${meta.volumes}"
        operator = "is_set"
      }
      driver = "docker"
      config {
        image = "drone/drone:1.9.1"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "${meta.volumes}/drone:/data",
        ]
        port_map {
          http = 80
        }
        privileged = "true"
      }
      env {
        DRONE_LOGS_DEBUG = "true"
        # https://discourse.drone.io/t/1-5-0-release-notes/5797
        DRONE_AGENTS_DISABLED = "true"

        DRONE_SERVER_HOST = "frisbee.grid.pub.ro"
        DRONE_SERVER_PROTO = "https"
        DRONE_RUNNER_ENVIRON = "VMCK_IP:10.42.1.1,VMCK_PORT:10001"
      }
      template {
        data = <<-EOF
          {{- with secret "kv/drone/github" }}
            DRONE_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
            DRONE_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
            DRONE_USER_FILTER = {{.Data.user_filter | toJSON }}
          {{- end }}
          {{- with secret "kv/drone/vault" }}
            DRONE_SECRET_PLUGIN_TOKEN = {{.Data.secret_plugin | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 200
        cpu = 200
        network {
          mbits = 1
          port "http" {
            static = 9997
          }
        }
      }
      service {
        name = "drone"
        port = "http"
        tags = [
          "ingress.enable=true",
          "ingress.frontend.rule=Host:frisbee.grid.pub.ro",
        ]
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "20s"
        }
      }
    }
  }
}
