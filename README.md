# puppet-openvox_gui

[![CI](https://github.com/miharp/puppet-openvox_gui/actions/workflows/ci.yml/badge.svg)](https://github.com/miharp/puppet-openvox_gui/actions/workflows/ci.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/miharp/openvox_gui.svg)](https://forge.puppet.com/modules/miharp/openvox_gui)
[![Apache-2 License](https://img.shields.io/github/license/miharp/puppet-openvox_gui.svg)](LICENSE)

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)

## Description

Installs and manages [OpenVox GUI](https://github.com/cvquesty/openvox-gui),
a web management console for OpenVox/Puppet infrastructure: dashboards,
certificate authority management, Bolt orchestration, PQL queries, and
report browsing. It is designed to run on the OpenVox Server itself and
talks to the local (or a remote) OpenVox Server and OpenVoxDB.

OpenVox GUI ships no OS packages; upstream installation is a git checkout
plus an interactive installer script. This module drives that installer
unattended and repeatably:

* checks out a pinned release tag with `vcsrepo`,
* pre-builds the React frontend (the installer's own build path
  bootstraps Node.js through dnf module streams, which no longer exist on
  EL10, and misses the rollup native binding on aarch64),
* renders the installer's answer file from the class parameters, and
* runs `install.sh -c` non-interactively, re-running it exactly when the
  pinned version or the configuration changes — which is the
  upstream-supported update flow.

## Setup

### What openvox_gui affects

* The source checkout (`/opt/openvox-gui-src`) and the application
  (`/opt/openvox-gui`), including a Python virtualenv, the `ovox` CLI,
  and the rendered `install.conf` answer file (root-only, contains the
  admin password). Installer runs log to
  `/var/log/openvox-gui-install.log`.
* The `openvox-gui` systemd service, running as the `puppet` user by
  default, and that user and group themselves (presence only; disable
  with `manage_service_user => false`).
* The `git`, `nodejs`, `npm`, and `diffutils` packages, plus
  `python3-venv` on the Debian family (disable with
  `manage_dependencies => false`).
* Via the upstream installer: the service user's sudoers rules in
  `/etc/sudoers.d/openvox-gui-users`, and SELinux booleans/port contexts
  on the RedHat family.

The module deliberately does **not** manage firewall rules, the GUI's
optional agent package mirror, or the ENC wiring in `puppet.conf` — those
stay under your control (see [Limitations](#limitations)).

### Setup requirements

* `sudo` must be installed: the upstream installer writes the service
  user's rules to `/etc/sudoers.d/`. The module does not manage the
  sudo package itself, to stay out of the way of modules that do
  (e.g. `saz/sudo`).
* Node.js >= 18 must be installable as the `nodejs` package (true on the
  supported platforms). On platforms whose default Node.js is older
  (e.g. EL9 ships 16), provide Node.js 18+ yourself and set
  `manage_dependencies => false`.
* Outbound HTTPS to github.com (git checkout) and to the npm and PyPI
  registries (frontend build, virtualenv creation).
* If `saz/sudo` manages the host with `purge => true`, keep it from
  deleting the installer's sudoers file:

```yaml
sudo::purge_ignore: 'openvox-gui-users'
```

### Beginning with openvox_gui

On the OpenVox Server, with TLS served from the node's own Puppet
certificate:

```puppet
class { 'openvox_gui':
  version        => '3.10.6',
  admin_password => Sensitive('supersecret'),
}
```

The GUI is then reachable at `https://<certname>:4567` (the certificate
covers the certname only). Log in as `admin` with the given password.

## Usage

### Pointing at remote backends

```puppet
class { 'openvox_gui':
  version            => '3.10.6',
  admin_password     => Sensitive('supersecret'),
  puppet_server_host => 'compiler01.example.com',
  puppetdb_host      => 'puppetdb.example.com',
}
```

### Arbitrary installer settings

Any `install.conf` setting without a dedicated parameter can be set (or
overridden) through `extra_settings`; the last assignment in the answer
file wins:

```puppet
class { 'openvox_gui':
  version        => '3.10.6',
  admin_password => Sensitive('supersecret'),
  extra_settings => {
    'OPENVOX_GUI_DB_BACKEND' => 'postgresql',
    'APP_DEBUG'              => true,
  },
}
```

### Opening the firewall

The module leaves the firewall to you, e.g. with `puppetlabs/firewall`:

```puppet
firewall { '200 allow openvox-gui':
  dport => 4567,
  proto => 'tcp',
  jump  => 'ACCEPT',
}
```

### Testing a fork or branch

```puppet
class { 'openvox_gui':
  version        => '3.10.6',
  admin_password => Sensitive('supersecret'),
  repo_source    => 'https://github.com/example/openvox-gui.git',
  revision       => 'my-feature-branch',
}
```

`version` still controls when the installer re-runs, so bump or change it
when the branch moves.

## Reference

Parameter documentation is in [REFERENCE.md](REFERENCE.md), generated
with puppet-strings (`bundle exec rake strings:generate:reference`).

## Limitations

* **Installer-based**: deployment runs upstream's `install.sh` under an
  idempotency guard, rather than managing every file as a Puppet
  resource. A run re-converges on the next agent run if the installer's
  final health check loses a race against a slow first service start.
  Don't delete the `.puppet-install.conf` / `.puppet-install-version`
  stamp files in the install directory — they are the "already
  installed" markers.
* **ENC**: the installer stages the GUI's external node classifier
  (`scripts/enc.py`) but never wires it into `puppet.conf`; enabling it
  is a manual, deliberate step. If your control repository classifies
  nodes with roles and profiles, leave it off.
* **Database**: SQLite (the upstream default) is assumed. The
  PostgreSQL/clustered backend can be selected via `extra_settings` but
  is untested by this module.
* Only the platforms in `metadata.json` are tested. EL9 works with
  `manage_dependencies => false` and a self-provided Node.js 18+
  (e.g. `dnf module switch-to nodejs:20`).
* The GUI polls the OpenVox Server's `/metrics/v2` (Jolokia) endpoint,
  which the default `auth.conf` denies; dashboard JVM metrics stay empty
  (and the journal logs 403s) until you allow it there.

## Development

Pull requests are welcome at
[miharp/puppet-openvox_gui](https://github.com/miharp/puppet-openvox_gui).

```bash
bundle install
bundle exec rake validate lint check rubocop  # static checks
bundle exec rake parallel_spec                # unit tests
BEAKER_HYPERVISOR=docker BEAKER_setfile=almalinux10-64 \
  bundle exec rake beaker                     # acceptance tests
```
