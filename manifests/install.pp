# @summary Checks out the OpenVox GUI source and pre-builds the frontend
#
# @api private
class openvox_gui::install {
  assert_private()

  $src_dir = $openvox_gui::src_dir
  $revision = pick($openvox_gui::revision, "v${openvox_gui::version}")

  # The installer's own user creation silently fails on hosts where the
  # service group does not pre-exist (its useradd discards errors), which
  # is every host without an OpenVox Server package. Only ensure and gid
  # are enforced, so a pre-existing user (e.g. 'puppet' on the server
  # itself) is left untouched.
  if $openvox_gui::manage_service_user {
    group { $openvox_gui::service_group:
      ensure => present,
      system => true,
    }

    user { $openvox_gui::service_user:
      ensure  => present,
      system  => true,
      gid     => $openvox_gui::service_group,
      require => Group[$openvox_gui::service_group],
    }
  }

  if $openvox_gui::manage_dependencies {
    package { $openvox_gui::dependency_packages:
      ensure => installed,
    }
    Package[$openvox_gui::dependency_packages] -> Vcsrepo[$src_dir]
    Package[$openvox_gui::dependency_packages] -> Exec['openvox_gui build frontend']
  }

  vcsrepo { $src_dir:
    ensure   => present,
    provider => git,
    source   => $openvox_gui::repo_source,
    revision => $revision,
  }

  # The React frontend is built here rather than by the installer: the
  # installer's own build path bootstraps Node.js via dnf module streams
  # (gone on EL10 with DNF5), and on aarch64 npm needs an explicit second
  # install of the rollup native binding
  # (https://github.com/npm/cli/issues/4828). The build script stamps
  # frontend/.built-version so the build only re-runs when the checked-out
  # VERSION changes.
  file { "${src_dir}/build-frontend.sh":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('openvox_gui/build-frontend.sh.epp', { 'src_dir' => $src_dir }),
    require => Vcsrepo[$src_dir],
  }

  # The UTF-8 locale keeps Puppet's output logging from choking on
  # npm's non-ASCII output (see the installer exec in config.pp).
  exec { 'openvox_gui build frontend':
    command     => "/bin/bash ${src_dir}/build-frontend.sh",
    unless      => "/usr/bin/cmp -s ${src_dir}/VERSION ${src_dir}/frontend/.built-version",
    environment => ['LANG=C.UTF-8', 'LC_ALL=C.UTF-8'],
    timeout     => $openvox_gui::build_timeout,
    require     => File["${src_dir}/build-frontend.sh"],
  }
}
