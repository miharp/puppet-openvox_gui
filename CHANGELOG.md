# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2] - 2026-08-26

* Shell-escape the values rendered into the installer's answer file: the
  installer sources it as shell, so a password containing `$`, spaces, or
  quotes was silently mangled or broke the run
* Only count a failed installer run as successful when the installer's
  own final health check is what failed: on an update the previous
  release keeps serving, so a run that died earlier could pass the probe
  and be stamped as installed
* Set `CONFIGURE_ENC=false` explicitly: from OpenVox GUI 3.12.0 the
  installer auto-detects a co-located OpenVox Server and rewrites
  `puppet.conf` to use the GUI's ENC
* Install `curl`, which the installer's health check and the module's own
  verification probe both need but nothing provided on minimal images
* Remove the installer's plaintext copy of the admin credentials
  (`config/.credentials`, owned by the service user) after each run
* Reject an `admin_password` containing single quotes or backslashes at
  compile time: the installer cannot pass them through to admin user
  creation and silently leaves no admin user
* Allow puppetlabs/stdlib 10

## [0.1.1] - 2026-08-20

* Verify a failed installer run with a scheme-aware health probe:
  upstream's final check curls plain http even when the GUI serves TLS,
  so TLS installs always reported failure despite a healthy service

## [0.1.0] - 2026-08-20

Initial release.

* Unattended, idempotent installation of OpenVox GUI from a pinned
  release tag, wrapping the upstream `install.sh`
* Frontend pre-build with EL10 (no dnf module streams) and aarch64
  (rollup native binding) support
* TLS via the node's Puppet certificate by default
* `extra_settings` passthrough for installer settings without a
  dedicated parameter
