# ACS vmchecker deployment

Deploy [vmck] and [acs-interface] using [Terraform].

[vmck]: https://github.com/vmck/vmck/
[acs-interface]: https://github.com/vmck/acs-interface/
[Terraform]: https://www.terraform.io/


## Setup

You need a [Nomad], [Consul] and [Vault] cluster running to be able to deploy
`vmck` and `acs-interface`. We recommend using [liquidinvestigations/cluster]. Please
refer to them on how to install the cluster.

[Nomad]: https://nomadproject.io/
[Consul]: https://www.consul.io/
[Vault]: https://www.vaultproject.io/
[liquidinvestigations/cluster]: https://github.com/liquidinvestigations/cluster


## HowTo
First read through the Terraform [Build Infrastructure tutorial] if you're new
to Terraform.

[Install Terraform], then run `terraform init` to download plugins.

```
$ terraform init
[...]
Terraform has been successfully initialized!
```

Terraform state is persisted in the cluster's consul so it's synchronized for
all users of this repo.

Make changes to the configuration files then run `./bin/deploy` to deploy.

```
$ ./bin/deploy
nomad_job.vmck: Refreshing state... [id=vmck]
nomad_job.acs-interface: Refreshing state... [id=acs-interface]

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

[Build Infrastructure tutorial]: https://learn.hashicorp.com/terraform/getting-started/build
[Install Terraform]: https://www.terraform.io/downloads.html


## Available scripts

### Backup - bin/backup

A script that does a backup on:

* Consul
* Acs-interface's Postgres database
* Acs-interface's Minio archives storage
* Vmck's Postgres database

It uses [borg] as the backup manager. It is recommended to set this script as
a cron job. Make sure you also have `pv` installed.

[borg]: https://borgbackup.readthedocs.io/en/stable/


### Consul state snapshot - bin/consul-snapshot

Takes a [snapshot] of the current state of consul.

[snapshot]: https://www.consul.io/api/snapshot.html


### Deploy - bin/deploy

Deploys the following jobs on the cluster:

* nomad_jobs/acs-interface.hcl
* nomad_jobs/drone.hcl
* nomad_jobs/ingress.hcl
* nomad_jobs/vmck.hcl


### Nomad exec - bin/nomad_exec

[Runs] the given command in the allocation's container.


[Runs]: https://nomadproject.io/docs/commands/alloc/exec/


## Additional optional nomad jobs

### Drone - nomad_jobs/drone.hcl

A [CI] that we use as the standard way of [building custom VM images].

[CI]: https://drone.io/
[building custom VM images]: https://github.com/vmck/image-builder


### Traefik - nomad_jobs/ingress.hcl

[Router] that we use to publish both `vmck` and `acs-interface`

[Router]: https://docs.traefik.io/


## Notes

* Currently all scripts have hardcoded IP adresses such as `10.42.2.2`. Please make
sure to change them to your respective interface IP adresses to ensure that the
deployment runs correctly.

* If you want to add more client nodes (i.e. more servers to the cluster) you can
use [vmck/cluster-client].

[vmck/cluster-client]: https://github.com/vmck/cluster-client


## Troubleshooting

**All of the following solutions consider that you are running on [liquidinvestigations/cluster].**

#### 1. Either `acs-interface` or `drone` does not have a ssl certificate

Usually traefik should take care of this and both `acs-interface` and `drone` should be available
through https. If that is not the case then:

* Go into Nomad UI and stop the job ingress
* Go to Consul UI, in the KV tab delete the ingress folder
* Restart traefik
* In 15 minutes you should have new certificates

[liquidinvestigations/cluster]: https://github.com/liquidinvestigations/cluster
