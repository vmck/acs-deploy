job "ingress" {

  datacenters = ["dc1"]
  type = "service"

  group "ingress" {

    task "traefik" {

      driver = "docker"

      config {
        image = "traefik:1.7"
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",
        ]
        port_map {
          http = 80
          https = 443
          admin = 8080
        }
      }

      template {
        destination = "local/traefik.toml"
        data = <<-EOF
          logLevel = "INFO"
          debug = false
          defaultEntryPoints = ["http", "https"]
          
          [api]
          entryPoint = "admin"
          
          [entryPoints]
            [entryPoints.http]
            address = ":80"
          
            [entryPoints.http.redirect]
            entryPoint = "https"
          
            [entryPoints.admin]
            address = ":8080"
          
            [entryPoints.https]
            address = ":443"
              [entryPoints.https.tls]
          
          [acme]
          email = "alex@grep.ro"
          entryPoint = "https"
          storage = "ingress/traefik/acme"
          onHostRule = true
          caServer = "https://acme-v02.api.letsencrypt.org/directory"
          acmeLogging = true
          [acme.httpChallenge]
            entryPoint = "http"
          
          [consulCatalog]
          endpoint = "http://{{ env "attr.unique.network.ip-address" }}:8500"
          prefix = "ingress"
          exposedByDefault = false
          
          [consul]
          endpoint = "http://{{ env "attr.unique.network.ip-address" }}:8500"
          prefix = "ingress/traefik"
          EOF
      }

      resources {
        memory = 100
        network {
          mbits = 1
          port "http" {
            static = 80
          }
          port "https" {
            static = 443
          }
          port "admin" {
            static = 8766
          }
        }
      }

      service {
        name = "traefik-http"
        port = "http"
      }

      service {
        name = "traefik-https"
        port = "https"
        check {
          name = "https"
          initial_status = "critical"
          type = "http"
          protocol = "https"
          path = "/"
          interval = "30s"
          timeout = "10s"
          tls_skip_verify = true
          header {
            Host = ["v2.vmchecker.cs.pub.ro"]
          }
        }
      }

      service {
        name = "traefik-admin"
        port = "admin"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/"
          interval = "30s"
          timeout = "10s"
        }
      }

    }

  }
}
