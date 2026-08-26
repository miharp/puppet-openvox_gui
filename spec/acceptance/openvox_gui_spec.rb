# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'openvox_gui' do
  # TLS is off because the acceptance host has no Puppet certificates
  # (the default ssl_cert/ssl_key reuse the node's own cert). The GUI
  # still starts with no OpenVox Server or PuppetDB reachable; its
  # dashboards just report the backends as down.
  let(:manifest) do
    <<~PUPPET
      class { 'openvox_gui':
        version        => '3.10.6',
        admin_password => Sensitive('acceptance-test-secret'),
        ssl_enabled    => false,
      }
    PUPPET
  end

  it_behaves_like 'an idempotent resource'

  describe file('/opt/openvox-gui-src/install.conf') do
    it { is_expected.to be_file }
    it { is_expected.to be_owned_by 'root' }
    it { is_expected.to be_mode 600 }
  end

  describe file('/opt/openvox-gui/config/.credentials') do
    it { is_expected.not_to exist }
  end

  describe service('openvox-gui') do
    it { is_expected.to be_running }
    it { is_expected.to be_enabled }
  end

  describe 'the OpenVox GUI API' do
    it 'requires authentication' do
      probe = 'curl --silent http://127.0.0.1:4567/api/health'
      result = shell("for i in $(seq 1 30); do #{probe} && exit 0; sleep 2; done; exit 1")
      expect(result.stdout).to match(/detail|status/)
    end
  end

  describe port(4567) do
    it { is_expected.to be_listening }
  end
end
