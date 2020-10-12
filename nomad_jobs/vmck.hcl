job "vmck" {
  datacenters = ["dc1"]
  type = "service"

  constraint {
    attribute = "${meta.vmck_ui}"
    operator = "is_set"
  }

  group "imghost" {
    task "nginx" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }
      driver = "docker"
      config {
        image = "nginx:mainline"
        volumes = [
          "${meta.volumes}/vmck-images:/usr/share/nginx/html",
          "local/nginx.conf:/etc/nginx/nginx.conf",
        ]
        port_map {
          http = 80
        }
      }
      resources {
        memory = 80
        cpu = 200
        network {
          port "http" {
            static = 10001
          }
        }
      }
      template {
        data = <<-EOF
          user  nginx;
          worker_processes auto;

          error_log  /var/log/nginx/error.log warn;
          pid        /var/run/nginx.pid;

          events {
            worker_connections 1024;
          }

          http {
            include       /etc/nginx/mime.types;
            default_type  application/octet-stream;

            sendfile on;
            sendfile_max_chunk 4m;
            aio threads;
            keepalive_timeout 100;
            server {
              listen 80;
              server_name  _;
              error_log /dev/stderr info;
              location / {
                root   /usr/share/nginx/html;
                autoindex on;
                proxy_max_temp_file_size 0;
                proxy_buffering off;
              }
              location = /healthcheck {
                stub_status;
              }
            }
          }
        EOF
        destination = "local/nginx.conf"
      }
      service {
        name = "vmck-imghost"
        port = "http"
      }
    }
  }

  group "database" {
    task "postgres" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }

      driver = "docker"
      config {
        image = "postgres:12.0-alpine"
        dns_servers = ["${attr.unique.network.ip-address}"]
        volumes = [
          "${meta.volumes}/database-vmck/postgres/data:/var/lib/postgresql/data",
        ]
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<-EOF
          {{- with secret "kv/vmck/postgres" }}
            POSTGRES_DB = "vmck"
            POSTGRES_USER = {{ .Data.username }}
            POSTGRES_PASSWORD = {{ .Data.password }}
          {{- end }}
          EOF
        destination = "local/postgres.env"
        env = true
      }
      resources {
        memory = 350
        network {
          mbits = 1
          port "pg" {
            static = 5431
          }
        }
      }
      service {
        name = "database-postgres-vmck"
        port = "pg"
        check {
          name = "tcp"
          initial_status = "critical"
          type = "tcp"
          interval = "5s"
          timeout = "5s"
        }
      }
    }
  }

  group "vmck" {
    restart {
      interval = "1m"
      attempts = 5
      delay = "5s"
      mode = "fail"
    }

    reschedule {
      delay = "30s"
      delay_function = "exponential"
      max_delay = "5m"
      unlimited = true
    }

    task "vmck" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }
      driver = "docker"
      config {
        image = "vmck/vmck:jw-raw_exec-qemu"
        hostname = "${attr.unique.hostname}"
        dns_servers = ["${attr.unique.network.ip-address}"]
        force_pull = true
        volumes = [
          "${meta.volumes}/vmck:/opt/vmck/data",
        ]
        port_map {
          http = 8000
        }
      }
      template {
        data = <<-EOF
          DEBUG = "true"
          HOSTNAME = "*"
          SSH_USERNAME = "vagrant"
          CONSUL_URL = "http://consul.service.consul:8500"
          NOMAD_URL = "http://nomad.service.consul:4646"
          VMCK_URL = 'http://{{ env "NOMAD_ADDR_http" }}'
          BACKEND = "qemu"
          QEMU_CPU_MHZ = 2500
          CHECK_SSH_SIGNATURE_TIMEOUT = "1"
          EOF
        destination = "local/vmck.env"
        env = true
      }
      template{
        data = <<-EOF
          {{- with secret "kv/vmck/django" -}}
            SECRET_KEY = "{{ .Data.secret_key }}"
          {{- end -}}
          EOF
        env = true
        destination = "local/vmck-key.env"
      }
      template{
        data = <<-EOF
          {{- with secret "kv/vmck/django" -}}
            SENTRY_DSN = "{{ .Data.sentry_sdk_dsn }}"
          {{- end -}}
          EOF
        env = true
        destination = "local/sentry_sdk_dsn.env"
      }
      template {
        data = <<-EOF
          QEMU_IMAGE_PATH_PREFIX = "http://{{ env "attr.unique.network.ip-address" }}:10001"
          EOF
        destination = "local/vmck-imghost.env"
        env = true
      }
      template {
        data = <<-EOF
          {{- with secret "kv/vmck/postgres" }}
            POSTGRES_USER = {{ .Data.username }}
            POSTGRES_PASSWORD = {{ .Data.password }}
          {{- end }}
          EOF
        destination = "local/postgres.env"
        env = true
      }
      template {
        data = <<-EOF
          POSTGRES_DB = "vmck"
          POSTGRES_ADDRESS = "{{ env "attr.unique.network.ip-address" }}"
          POSTGRES_PORT = "5431"
          EOF
        destination = "local/postgres-api.env"
        env = true
      }
      resources {
        memory = 450
        cpu = 450
        network {
          port "http" {
            static = 10000
          }
        }
      }
      service {
        name = "vmck"
        port = "http"
        check {
          name = "vmck alive on http"
          initial_status = "critical"
          type = "http"
          path = "/v0/"
          interval = "5s"
          timeout = "5s"
        }
      }
    }
  }
}
