# frozen_string_literal: true

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  # sudo is a documented system prerequisite (the upstream installer
  # writes to /etc/sudoers.d, and the module deliberately does not manage
  # the sudo package to avoid conflicting with e.g. saz/sudo). Minimal
  # Ubuntu images ship without it; on the RedHat family it is present.
  # curl, which the specs also use to probe the GUI API, is deliberately
  # not pre-installed: the module installs it, and the run must prove so.
  host.install_package('sudo') if fact_on(host, 'os.family') == 'Debian'
end
