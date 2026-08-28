# @summary Wires a catalog compiler to the OpenVox GUI's node classifier
#
# Compilers, not consoles, classify nodes: puppetserver runs an
# `external_nodes` script at compile time. OpenVox GUI ships that script
# (`scripts/enc.py`); it asks a console's API for the node's environment,
# classes and parameters, and answers with an empty classification when
# no console responds, so a console outage slows compiles (each waits out
# the request timeout) rather than failing them. This class installs the
# script, hands it the console URL(s) through an environment file that
# puppetserver's unit loads, and points `puppet.conf` at it — the steps
# of upstream's `scripts/bootstrap-compiler-enc.sh`, as managed resources.
#
# The script is this module's copy of upstream's (from OpenVox GUI
# 3.12.1-dev.10); `enc_source` can point at another, such as the one
# under a console's install directory.
#
# Classes the GUI assigns are merged with whatever `site.pp` declares,
# so an existing roles-and-profiles classification keeps working when
# this is enabled; the GUI adds to it.
#
# @example A compiler classified by one console
#   class { 'openvox_gui::enc':
#     api_base => ['https://console.example.com:4567'],
#   }
#
# @example Two consoles sharing a database, tried in order
#   class { 'openvox_gui::enc':
#     api_base => ['https://console-a.example.com:4567', 'https://console-b.example.com:4567'],
#   }
#
# @param api_base
#   Console URL(s) the classifier asks, in order; the first to answer
#   wins. Two consoles are a failover pair only when they share the GUI's
#   database — a console with an empty classifier answers, too.
# @param ensure
#   'absent' removes the wiring: the `puppet.conf` settings, the
#   environment file, the drop-in and the script.
# @param enc_path
#   Where the classifier script is installed. Upstream's convention.
# @param enc_source
#   Puppet file source of the classifier script.
# @param sysconfig
#   Environment file the puppetserver unit loads the console URL(s) from.
# @param ca_file
#   CA bundle the script verifies the console's certificate against.
#   Unset, the script uses the Puppet agent's CA certificate, which is
#   right when the GUI serves a certificate from the Puppet CA (the
#   installer's default).
# @param tls_verify
#   Whether the script verifies the console's certificate at all.
# @param manage_puppet_conf
#   Set `node_terminus` and `external_nodes` in `puppet.conf`'s [server]
#   section.
# @param puppet_conf
#   Path of `puppet.conf`.
# @param service
#   Name of the puppetserver unit: the drop-in goes under its `.d`
#   directory, and it is restarted when the wiring changes.
# @param restart_service
#   Whether to notify `Service[$service]`, which must then be declared
#   elsewhere in the catalog. Disable to handle restarts yourself.
# @param manage_pyyaml
#   Install the PyYAML package the script imports. Left installed on
#   `ensure => absent`.
# @param pyyaml_package
#   Name of that package.
class openvox_gui::enc (
  Array[Stdlib::HTTPUrl, 1] $api_base,
  Enum['present', 'absent'] $ensure = 'present',
  Stdlib::Absolutepath $enc_path = '/usr/local/bin/enc.py',
  String[1] $enc_source = 'puppet:///modules/openvox_gui/enc.py',
  Stdlib::Absolutepath $sysconfig = $facts['os']['family'] ? {
    'Debian' => '/etc/default/openvox-enc',
    default  => '/etc/sysconfig/openvox-enc',
  },
  Optional[Stdlib::Absolutepath] $ca_file = undef,
  Boolean $tls_verify = true,
  Boolean $manage_puppet_conf = true,
  Stdlib::Absolutepath $puppet_conf = '/etc/puppetlabs/puppet/puppet.conf',
  String[1] $service = 'puppetserver',
  Boolean $restart_service = true,
  Boolean $manage_pyyaml = true,
  String[1] $pyyaml_package = $facts['os']['family'] ? {
    'Debian' => 'python3-yaml',
    default  => 'python3-pyyaml',
  },
) {
  $file_ensure = $ensure ? {
    'present' => 'file',
    default   => 'absent',
  }
  $dropin_dir = "/etc/systemd/system/${service}.service.d"
  $dropin = "${dropin_dir}/openvox-enc.conf"
  $restart = $restart_service ? {
    true    => [Service[$service]],
    default => [],
  }

  if $manage_pyyaml and $ensure == 'present' {
    package { $pyyaml_package:
      ensure => installed,
      before => File[$enc_path],
    }
  }

  file { $enc_path:
    ensure => $file_ensure,
    source => $enc_source,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    notify => $restart,
  }

  $env = [
    "OPENVOX_GUI_API_BASE=${api_base.join(',')}",
    $ca_file ? {
      undef   => undef,
      default => "OPENVOX_GUI_ENC_CA=${ca_file}",
    },
    $tls_verify ? {
      true    => undef,
      default => 'OPENVOX_GUI_ENC_TLS_VERIFY=0',
    },
  ].filter |$line| { $line =~ NotUndef }

  file { $sysconfig:
    ensure  => $file_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet (openvox_gui::enc).\n${env.join("\n")}\n",
    notify  => $restart,
  }

  # The unit, not a shell, must load the environment file: puppetserver
  # inherits nothing from an operator's session.
  file { $dropin_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { $dropin:
    ensure  => $file_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet (openvox_gui::enc).\n[Service]\nEnvironmentFile=-${sysconfig}\n",
    notify  => Exec['openvox_gui::enc daemon-reload'],
  }

  exec { 'openvox_gui::enc daemon-reload':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
    notify      => $restart,
  }

  if $manage_puppet_conf {
    ini_setting { 'openvox_gui::enc node_terminus':
      ensure  => $ensure,
      path    => $puppet_conf,
      section => 'server',
      setting => 'node_terminus',
      value   => 'exec',
      notify  => $restart,
    }

    ini_setting { 'openvox_gui::enc external_nodes':
      ensure  => $ensure,
      path    => $puppet_conf,
      section => 'server',
      setting => 'external_nodes',
      value   => $enc_path,
      notify  => $restart,
    }
  }
}
