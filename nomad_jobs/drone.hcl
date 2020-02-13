job "drone" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "drone" {
    task "drone" {
      constraint {
        attribute = "${meta.vmck_worker}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        image = "drone/drone:1.6.5"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
        ]
        port_map {
          http = 80
        }
      }
      env {
        DRONE_LOGS_DEBUG = "true"
        # https://discourse.drone.io/t/1-5-0-release-notes/5797
        DRONE_AGENTS_DISABLED = "true"
        DRONE_USER_AGENT = "username:gmuraru,admin:true"

        DRONE_GITHUB_SERVER = "https://github.com"
        DRONE_SERVER_HOST = "frisbee.vmchecker.cs.pub.ro"
        DRONE_SERVER_PROTO = "https"
        DRONE_RUNNER_ENVIRON = "VMCK_IP:10.42.2.2,VMCK_PORT:10000"
      }
      template {
        data = <<-EOF
          {{- with secret "kv/drone/github" }}
            DRONE_GITHUB_CLIENT_ID = {{.Data.client_id | toJSON }}
            DRONE_GITHUB_CLIENT_SECRET = {{.Data.client_secret | toJSON }}
            DRONE_USER_FILTER = {{.Data.user_filter | toJSON }}
          {{- end }}
        EOF
        destination = "local/drone.env"
        env = true
      }
      resources {
        memory = 250
        cpu = 150
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
          "ingress.frontend.rule=Host:frisbee.vmchecker.cs.pub.ro",
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
