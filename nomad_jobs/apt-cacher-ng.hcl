job "apt-cacher-ng" {
  datacenters = ["dc1"]
  type = "service"

  group "apt-cacher-ng" {
    task "apt-cacher-ng" {
      constraint {
        attribute = "${meta.volumes}"
        operator  = "is_set"
      }
      driver = "docker"
      config {
        image = "sameersbn/apt-cacher-ng:3.1-3"
        volumes = [
          "${meta.volumes}/apt-cacher-ng:/var/cache/apt-cacher-ng",
        ]
        port_map {
          http = 3142
        }
      }
      resources {
        memory = 200
        cpu = 100
        network {
          port "http" {
            static = 9100
          }
        }
      }
      service {
        name = "apt-cacher-ng"
        port = "http"
        check {
          name = "apt-cacher-ng alive on http"
          initial_status = "critical"
          type = "tcp"
          interval = "5s"
          timeout = "5s"
        }
      }
    }
  }
}
