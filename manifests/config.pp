# @summary Renders the installer answer file and applies it
#
# For an installer-based application, running the installer is how
# configuration is applied: `install.sh -c install.conf` both deploys the
# application and writes its runtime configuration, and re-running it is
# the upstream-supported update flow.
#
# @api private
class openvox_gui::config {
  assert_private()

  $src_dir = $openvox_gui::src_dir
  $install_dir = $openvox_gui::install_dir

  $ssl_cert = pick(
    $openvox_gui::ssl_cert,
    "/etc/puppetlabs/puppet/ssl/certs/${trusted['certname']}.pem",
  )
  $ssl_key = pick(
    $openvox_gui::ssl_key,
    "/etc/puppetlabs/puppet/ssl/private_keys/${trusted['certname']}.pem",
  )

  # The answer file carries the admin password, so it is root-only and
  # kept out of diffs.
  file { "${src_dir}/install.conf":
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0600',
    show_diff => false,
    content   => Sensitive(epp('openvox_gui/install.conf.epp', {
      'install_dir'        => $install_dir,
      'app_port'           => $openvox_gui::app_port,
      'app_host'           => $openvox_gui::app_host,
      'puppet_server_host' => $openvox_gui::puppet_server_host,
      'puppet_server_port' => $openvox_gui::puppet_server_port,
      'puppetdb_host'      => $openvox_gui::puppetdb_host,
      'puppetdb_port'      => $openvox_gui::puppetdb_port,
      'ssl_enabled'        => $openvox_gui::ssl_enabled,
      'ssl_cert'           => $ssl_cert,
      'ssl_key'            => $ssl_key,
      'auth_backend'       => $openvox_gui::auth_backend,
      'admin_username'     => $openvox_gui::admin_username,
      'admin_password'     => $openvox_gui::admin_password.unwrap,
      'service_user'       => $openvox_gui::service_user,
      'service_group'      => $openvox_gui::service_group,
      'uvicorn_workers'    => $openvox_gui::uvicorn_workers,
      'configure_selinux'  => $openvox_gui::configure_selinux,
      'extra_settings'     => $openvox_gui::extra_settings,
    })),
  }

  # On success the answer file and source VERSION are stamped into the
  # install directory, so the installer re-runs exactly when the pinned
  # release or the configuration changed. If a run fails partway (the
  # installer's final health check can lose a race against a slow first
  # service start), the stamps stay unwritten and the next agent run
  # re-converges.
  $stamp_conf = "${install_dir}/.puppet-install.conf"
  $stamp_version = "${install_dir}/.puppet-install-version"
  $install_cmd = [
    'bash install.sh -c install.conf',
    "install -m 0600 install.conf ${stamp_conf}",
    "install -m 0644 VERSION ${stamp_version}",
  ].join(' && ')

  exec { 'openvox_gui run installer':
    command => "/bin/bash -c '${install_cmd}'",
    cwd     => $src_dir,
    unless  => "/bin/bash -c 'cmp -s install.conf ${stamp_conf} && cmp -s VERSION ${stamp_version}'",
    timeout => $openvox_gui::install_timeout,
    require => File["${src_dir}/install.conf"],
  }
}
