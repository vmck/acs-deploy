job "acs-interface" {
  datacenters = ["dc1"]
  type = "service"

  constraint {
    attribute = "${meta.vmck_worker}"
    operator = "is_set"
  }

  group "storage" {
    task "minio" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }
      driver = "docker"
      config {
        image = "minio/minio:RELEASE.2019-09-26T19-42-35Z"
        dns_servers = ["${attr.unique.network.ip-address}"]
        command = "server"
        args = ["/data"]
        volumes = [
          "${meta.volumes}/minio-storage:/data",
        ]
        port_map {
          http = 9000
        }
      }
      template {
        data = <<-EOF
          {{- with secret "kv/acs-interface/minio" -}}
            MINIO_ACCESS_KEY = "{{ .Data.access_key }}"
            MINIO_SECRET_KEY = "{{ .Data.secret_key }}"
            MINIO_BROWSER = "on"
          {{- end -}}
        EOF
        destination = "local/config.env"
        env = true
      }
      resources {
        memory = 200
        cpu = 100
        network {
          port "http" {
            static = 9000
          }
        }
      }
      service {
        name = "storage"
        port = "http"
        check {
          name = "storage alive on http"
          initial_status = "critical"
          type = "tcp"
          interval = "5s"
          timeout = "5s"
        }
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
          "${meta.volumes}/database/postgres/data:/var/lib/postgresql/data",
        ]
        port_map {
          pg = 5432
        }
      }
      template {
        data = <<-EOF
          POSTGRES_DB = "interface"
          {{- with secret "kv/acs-interface/postgres" }}
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
            static = 26669
          }
        }
      }
      service {
        name = "database-postgres-interface"
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

  group "acs-interface" {
    task "acs-interface" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }
      driver = "docker"
      config {
        image = "vmck/acs-interface:0.4.0"
        dns_servers = ["${attr.unique.network.ip-address}"]
        volumes = [
          "${meta.volumes}/acs-interface:/opt/interface/data",
        ]
        port_map {
          http = 8100
        }
      }
      template {
        data = <<-EOF
          HOSTNAME = "*"
          ACS_INTERFACE_ADDRESS = "http://{{ env "NOMAD_ADDR_http" }}"
          MANAGER_TAG = "0.3.2"
          EOF
          destination = "local/interface.env"
          env = true
      }
      template{
        data = <<-EOF
          {{- with secret "kv/acs-interface/django" -}}
            SECRET_KEY = "{{ .Data.secret_key }}"
          {{- end -}}
          EOF
        env = true
        destination = "local/interface-key.env"
      }
      template {
        data = <<-EOF
          VMCK_API_URL = "http://{{ env "attr.unique.network.ip-address" }}:10000/v0/"
          EOF
          env = true
          destination = "local/vmck-api.env"
      }
      template {
        data = <<-EOF
          MINIO_ADDRESS = "{{ env "attr.unique.network.ip-address" }}:9000"
          EOF
          destination = "local/minio-api.env"
          env = true
      }
      template {
        data = <<-EOF
          {{- with secret "kv/acs-interface/minio" -}}
            MINIO_ACCESS_KEY = "{{ .Data.access_key }}"
            MINIO_SECRET_KEY = "{{ .Data.secret_key }}"
            MINIO_BUCKET = "test"
          {{- end -}}
          EOF
          destination = "local/minio.env"
          env = true
      }
      template {
        data = <<-EOF
          {{- with secret "kv/acs-interface/postgres" }}
            POSTGRES_USER = {{ .Data.username }}
            POSTGRES_PASSWORD = {{ .Data.password }}
          {{- end }}
          EOF
          destination = "local/postgres.env"
          env = true
      }
      template {
        data = <<-EOF
          POSTGRES_DB = "interface"
          POSTGRES_ADDRESS = "{{ env "attr.unique.network.ip-address" }}"
          POSTGRES_PORT = "26669"
          EOF
          destination = "local/postgres-api.env"
          env = true
      }
      template {
        data = <<-EOF
          {{- with secret "kv/acs-interface/ldap" -}}
            LDAP_SERVER_URL = "{{ .Data.server_address }}"
            LDAP_SERVER_URI = "ldaps://{{ .Data.server_address }}:{{ .Data.server_port }}"
            LDAP_BIND_DN = "{{ .Data.bind_dn }}"
            LDAP_BIND_PASSWORD = "{{ .Data.bind_password }}"
            LDAP_USER_TREE = "{{ .Data.user_tree }}"
            LDAP_USER_FILTER = "{{ .Data.user_filter }}"
          {{- end -}}
          EOF
          destination = "local/ldap.env"
          env = true
      }
      resources {
        memory = 300
        cpu = 500
        network {
          port "http" {
            static = 10002
          }
        }
      }
      service {
        name = "acs-interface"
        port = "http"
        check {
          name = "acs-interface alive on http"
          initial_status = "critical"
          type = "http"
          path = "/alive"
          interval = "5s"
          timeout = "5s"
        }
        tags = [
          "ingress.enable=true",
          "ingress.frontend.rule=Host:v2.vmchecker.cs.pub.ro",
        ]
      }
    }
  }
}
