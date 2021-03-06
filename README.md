## Short instructions

If you don't want to go through all README file, you can use following steps to create all necessary assets for deploying BOSH and CF to OpenStack on Power architecture:

1. Create "injector" VM with __m1.small__ flavor and Ubuntu 14.04 LE as operating system. And make it possible to SSH to the VM. In case you use password authentication for SSH or sudo user, you will need to uncomment `ask_pass` or `ask_sudo_pass` options in `ansible.cfg` file. This VM will be used to run Ansible playbooks that create jumpbox, stemcell and binary builders. This is needed to minimize impact of network problems on the deployment process.
1. Create "jumpbox" VM with __m1.xlarge__ flavor (the size is important here) and Ubuntu 14.04 LE operating system. 
1. Make it possible to establish SSH connection from "injector" to "jumpbox".
1. Enter "injector" VM by SSH and run [this script](https://gist.github.com/allomov/46b5b936a3ffce152933#file-bootstrap-jumpbox-sh) to bootstrap "jumpbox" and create all necessary assets. After that you can use "jumpbox" to deploy MicroBOSH and CF.
1. Enter "jumpbox" VM by SSH.
1. Build all necessary assets: stemcell, opetstack cpi and BOSH release. You can use [this script](https://gist.github.com/allomov/46b5b936a3ffce152933#file-deploy-microbosh-sh) as an example of how to do it.
1. After you deployed MicroBOSH, you'll need to find out what's MicroBOSH in private network, then SSH to the MicroBOSH instance and replace MicroBOSH floating IP to its IP in a private network in a following file `/var/vcap/jobs/cpi/config/cpi.yml`. This made to allow compilation VMs to communicate with BOSH director in MicroBOSH instance. 
1. Clone [workspace project](https://github.com/Altoros/ibm-power-bosh-workspace) and follow instructions in its README.

## Install [Ansible](http://www.ansible.com/)

The recommended ansible version is 1.9.2 (install from [PyPI](https://pypi.python.org/pypi/ansible/1.9.2)). The earlier versions may come with [this bug](https://github.com/rvm/rvm1-ansible/issues/44).

You can also use `brew` tool to install latest version on your Mac OS. Simply run `brew install ansible`.

## Setup VMs

Playbooks are intended to be run on virtual machines powering Ubuntu 14.04 with ppc64el arch, this VMs should have python 2.5+ to be installed.

We recommend using a separate VM as a jumpbox and 2 separate VMs for bulding stemcell and binaries, still you can build everything you need on a single VM using `all-in-one`.

## Provision jumpbox VM

From your local host:

1. Run `sudo ansible-galaxy install rvm_io.rvm1-ruby`
1. Clone the [repo](https://github.com/Altoros/power-bosh-jumpbox-bootstrap.git) and enter its root
1. Run `cp hosts.example hosts`
1. Open `hosts` file and change x.x.x.x to an jumpbox's public IP
1. Run `ansible-playbook jumpbox-playbook.yml` to provision a VM

### Roles

List of roles included in this project:

1. `gccgo` is used to install gccgo (version 5.1 by default), at this moment works only for power 8.
1. `common` performs apt-get update and installs all necessary packages, creates ~/github folder and installs direnv, installs RVM with Ruby 2.1.4, installs BOSH with all necessary gems; all roles that are applied to hosts depend on it; depends on `gccgo` and `rvm_io.rvm1-ruby`.
1. `jumpbox` creates an environment to run other playbooks, BOSH CLI commands, CF CLI commands and bosh-init; depends on `common`.
1. `binaries-builder` is used to build binaries for IBM Power BOSH and CF installations.
1. `stemcell-builder` installs everything that is needed to run stemcell builder of the BOSH project.


## Build a stemcell

You should create a separate VM to build a stemcell. VM capacity should fit the OpenStack __m1.large__ [flavor](http://docs.openstack.org/openstack-ops/content/flavors.html).

The playbook for building stemcells is the work in progress so far. In order to build a stemcell make the following steps:

1. ssh to a stemcell builder instance: `ssh -i ~/.ssh/id_rsa ubuntu@x.x.x.x`
1. `cd ~/stemcell-builder`
1. `gem install bundler && bundle install`
1. Run `/home/ubuntu/stemcell-builder/bin/build-stemcell` (if any errors occurs, try to run commands from this script manually).

Notice: At this moment we use the [power-2915 branch](https://github.com/Altoros/bosh/tree/power-2915) of BOSH. This branch doesn't add an extra MicroBOSH release to the stemcell, which is not needed at all, since we use `bosh-init` tool for MicroBOSH deployment.

## Build binaries for MicroBOSH and Cloud Foundry releases

`binaries-playbook.yml` is used for building binaries. To build all the binaries for both BOSH and CF execute:

```
ansible-playbook binaries-playbook.yml
```

You can only make binaries for BOSH:

```
ansible-playbook binaries-playbook.yml --tags "bosh"
```

Or for CF:

```
ansible-playbook binaries-playbook.yml --tags "cf"
```

The binaries and the directory structure can be configured via the `group_vars/binaries-builder/packages` config file. The file is in YAML format and contains the following properties

* `scripts_path` - the folder playbook copies its compilation scripts into.
* `source_root_path` - the folder to download the original binaries into.
* `result_root_path` - the folder with the results of binary building organized in the same way binaries are organized in the `blobs` folder of the corresponging BOSH release folder.
* `build_root_path` - the folder to build the packages in.

In each of these folders playbook creates `bosh` and `cf` folders to organize the namespaces for BOSH and CF binaries.

Packages to build for BOSH and CF are described in `bosh_packages` and `cf_packages` lists correspondingly. Each entry in the list describes an individual binary and consists of the following properties:

* `name` - a descriptive name of the blob to use in the process of downloading and building; since it is used to name some intermediate folders it has to be unique.
* `url` - the URL to download the blob from; has to be '' if a package is not downloaded by plain HTTP (eg git, APT, etc).
* `slug` - a short identifier to use with the `--compile-only` option.
* `action` - one of `change_config` and `compile`; in case of `change_config` playbook simply replaces all the occurences of the `config.guess` and `config.sub` files; in case of `compile`, in addition to aforementioned, it compiles the package from source.
* `script` - a path (relative to the `scripts_path` folder) to a bash script used to compile the package.
* `bosh_blob_path` - the blob path in the filesystem relative to the `blobs` folder required by BOSH.
* `bosh_blob` - the name of the blob required by BOSH including the filetype extension.
* `bosh_blob_name` - the name of the blob required by BOSH without the filetype extension.

`bosh_blob` and `bosh_blob_name` are both here for 2 reasons:
1. BOSH may require the archive to contain a folder with the same name and we do not want to parse it from the archive name.
2. BOSH may require different file type extensions depending on the package.

You can optionally compile a specific package only by specifying the `compile_only` variable equal to the corresponding slug:

```
ansible-playbook binaries-playbook.yml --extra-vars="compile_only=postgres"
```

Note that PowerDNS depends on PostgreSQL so don't build it before you build PostgreSQL.

## Contacts

If you have any questions, write to Alexander Lomov (alexander.lomov@altoros.com) or Lev Berman (lev.berman@altoros.com).

## TODO

1. put in an order arguments of binaries builder script.
1. move shared contrib extentions to postgresql folder https://github.com/cloudfoundry/cf-release/blob/v207/jobs/postgres/templates/postgres_ctl.erb#L109
