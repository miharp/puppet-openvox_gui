# @summary Installs and manages OpenVox GUI
#
# Installs [OpenVox GUI](https://github.com/cvquesty/openvox-gui), a web
# management console (dashboards, CA management, Bolt orchestration, PQL)
# for OpenVox/Puppet infrastructure, and manages its systemd service.
#
# OpenVox GUI ships no packages; upstream installation is a git checkout
# plus an interactive installer script. This module drives that installer
# unattended: it checks out the pinned release tag, pre-builds the React
# frontend (the installer's own build path bootstraps Node.js through dnf
# module streams, which no longer exist on EL10), renders the installer's
# answer file, and runs `install.sh -c` non-interactively. Changing
# `version` or any configuration parameter re-runs the installer, which is
# the upstream-supported update flow.
#
# The GUI's optional firewall, agent package mirror, and ENC integrations
# are left off; manage the firewall port and puppet.conf wiring outside
# this module. The installer writes sudoers rules for the service user to
# `/etc/sudoers.d/openvox-gui-users`; if `saz/sudo` manages that host with
# `purge => true`, set `sudo::purge_ignore: 'openvox-gui-users'`.
#
# @example All-in-one deployment on the OpenVox Server
#   class { 'openvox_gui':
#     version        => '3.10.6',
#     admin_password => Sensitive('supersecret'),
#   }
#
# @example Without TLS, on a nonstandard port
#   class { 'openvox_gui':
#     version        => '3.10.6',
#     admin_password => Sensitive('supersecret'),
#     ssl_enabled    => false,
#     app_port       => 8080,
#   }
#
# @param version
#   The OpenVox GUI release to install, e.g. '3.10.6'. Used to select the
#   git release tag ('v' plus this value, unless `revision` overrides it)
#   and to decide when an update run is needed.
# @param admin_password
#   Password of the initial admin user, created on first install when
#   auth_backend is 'local'.
# @param admin_username
#   Name of the initial admin user.
# @param app_port
#   Port the web interface listens on.
# @param app_host
#   Address the web interface binds to.
# @param install_dir
#   Directory the application is installed into.
# @param src_dir
#   Directory the git checkout (the installer's working directory) lives in.
# @param repo_source
#   Git repository to install from. Point this at a fork to test patches.
# @param revision
#   Git revision to check out. Defaults to the release tag 'v<version>'.
# @param puppet_server_host
#   Hostname of the OpenVox Server (compiler) the GUI talks to.
# @param puppet_server_port
#   Port of the OpenVox Server.
# @param puppetdb_host
#   Hostname of the OpenVoxDB instance the GUI queries.
# @param puppetdb_port
#   Port of the OpenVoxDB API.
# @param ssl_enabled
#   Whether the GUI itself serves HTTPS. The defaults for `ssl_cert` and
#   `ssl_key` reuse the node's own Puppet certificate, which covers the
#   certname only — browse to the GUI by that name.
# @param ssl_cert
#   Certificate the GUI listener presents. Defaults to the node's Puppet
#   certificate.
# @param ssl_key
#   Private key of the GUI listener. Defaults to the node's Puppet private
#   key, which the default service user 'puppet' can read.
# @param auth_backend
#   'local' for username/password authentication, 'none' to disable
#   authentication entirely.
# @param service_user
#   System user the service runs as. The installer creates it if missing
#   and adds it to the 'puppet' group for certificate access.
# @param service_group
#   Group the service runs as.
# @param uvicorn_workers
#   Number of uvicorn worker processes serving the backend.
# @param configure_selinux
#   Whether the installer sets SELinux booleans and port contexts for the
#   GUI. Defaults to true on the RedHat family.
# @param extra_settings
#   Additional KEY=value pairs appended to the installer's answer file,
#   overriding anything this module set. Use for installer settings
#   without a dedicated parameter, e.g. a PostgreSQL backend:
#   { 'OPENVOX_GUI_DB_BACKEND' => 'postgresql' }.
# @param manage_dependencies
#   Whether to manage the packages needed to check out the source and
#   build the frontend. Set to false to provide git and Node.js >= 18
#   yourself (required on platforms whose default Node.js is older).
# @param dependency_packages
#   The packages installed when manage_dependencies is true.
# @param build_timeout
#   Seconds the frontend npm build may take.
# @param install_timeout
#   Seconds the installer run may take.
# @param service_manage
#   Whether to manage the service at all.
# @param service_name
#   Name of the systemd service the installer creates.
# @param service_ensure
#   Desired run state of the service.
# @param service_enable
#   Whether the service starts on boot.
class openvox_gui (
  String[1] $version,
  Sensitive[String[1]] $admin_password,
  String[1] $admin_username = 'admin',
  Stdlib::Port $app_port = 4567,
  String[1] $app_host = '0.0.0.0',
  Stdlib::Absolutepath $install_dir = '/opt/openvox-gui',
  Stdlib::Absolutepath $src_dir = '/opt/openvox-gui-src',
  String[1] $repo_source = 'https://github.com/cvquesty/openvox-gui.git',
  Optional[String[1]] $revision = undef,
  Stdlib::Host $puppet_server_host = $facts['networking']['fqdn'],
  Stdlib::Port $puppet_server_port = 8140,
  Stdlib::Host $puppetdb_host = $facts['networking']['fqdn'],
  Stdlib::Port $puppetdb_port = 8081,
  Boolean $ssl_enabled = true,
  Optional[Stdlib::Absolutepath] $ssl_cert = undef,
  Optional[Stdlib::Absolutepath] $ssl_key = undef,
  Enum['local', 'none'] $auth_backend = 'local',
  String[1] $service_user = 'puppet',
  String[1] $service_group = 'puppet',
  Integer[1] $uvicorn_workers = 2,
  Boolean $configure_selinux = $facts['os']['family'] == 'RedHat',
  Hash[String[1], Variant[String, Integer, Boolean]] $extra_settings = {},
  Boolean $manage_dependencies = true,
  Array[String[1]] $dependency_packages = ['git', 'nodejs', 'npm'],
  Integer[1] $build_timeout = 600,
  Integer[1] $install_timeout = 900,
  Boolean $service_manage = true,
  String[1] $service_name = 'openvox-gui',
  Stdlib::Ensure::Service $service_ensure = 'running',
  Boolean $service_enable = true,
) {
  contain openvox_gui::install
  contain openvox_gui::config
  contain openvox_gui::service

  Class['openvox_gui::install']
  -> Class['openvox_gui::config']
  ~> Class['openvox_gui::service']
}
