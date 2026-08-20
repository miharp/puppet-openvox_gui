# frozen_string_literal: true

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  # curl is used by the acceptance specs to probe the GUI API; sudo is a
  # documented system prerequisite (the upstream installer writes to
  # /etc/sudoers.d, and the module deliberately does not manage the sudo
  # package to avoid conflicting with e.g. saz/sudo). Minimal Ubuntu
  # images ship neither; on the RedHat family both are already present.
  if fact_on(host, 'os.family') == 'Debian'
    host.install_package('curl')
    host.install_package('sudo')
  end
end
