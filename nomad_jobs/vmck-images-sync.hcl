job "vmck-images-sync" {
  datacenters = ["dc1"]
  type = "batch"

  periodic {
    cron = "* * * * *"
    prohibit_overlap = true
  }

  constraint {
    attribute = "${meta.volumes}"
    operator  = "is_set"
  }

  constraint {
    attribute = "${meta.vmck_ci}"
    operator  = "is_set"
  }

  group "sync" {
     task "rsync" {
      driver = "docker"
      config {
        image = "eeacms/rsync:2.3"
        volumes = [
          "${meta.volumes}/.ssh:/root/ssh-conf",
          "${meta.volumes}/vmck-images:/vmck-images"
        ]
        command = "/bin/sh"
        args = [
          "-c",
          "cp /root/ssh-conf/* /root/.ssh/; rsync -avzx --numeric-ids /vmck-images/ compute:${meta.volumes}/vmck-images/"
        ]
      }
     }
  }
}
