# frozen_string_literal: true

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  # curl is used by the acceptance specs to probe the GUI API. On the
  # RedHat family it is already provided by curl-minimal.
  host.install_package('curl') if fact_on(host, 'os.family') == 'Debian'
end
