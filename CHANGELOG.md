# Changelog

All notable changes to this project will be documented in this file.

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
