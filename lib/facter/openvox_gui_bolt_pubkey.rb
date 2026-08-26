# frozen_string_literal: true

# The OpenVox GUI installer generates the SSH key its orchestration uses
# at /etc/puppetlabs/bolt/id_bolt on the console. Exposing the public
# half as a fact lets targets collect it (for example with
# puppetdb_query, see openvox_gui::bolt_target) instead of copying it.
Facter.add(:openvox_gui_bolt_pubkey) do
  pubkey = '/etc/puppetlabs/bolt/id_bolt.pub'
  confine { File.readable?(pubkey) }
  setcode do
    key = File.read(pubkey).strip
    key.empty? ? nil : key
  end
end
