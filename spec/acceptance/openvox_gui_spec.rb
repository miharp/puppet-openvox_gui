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

      # The console orchestrating itself: the same host is also a target.
      class { 'openvox_gui::bolt_target':
        authorized_keys => ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcceptanceTestKeyOnlyNotReal openvox-gui-bolt'],
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

  describe user('bolt') do
    it { is_expected.to exist }
    it { is_expected.to belong_to_primary_group 'bolt' }
    it { is_expected.to have_home_directory '/home/bolt' }
  end

  describe file('/home/bolt/.ssh/authorized_keys') do
    it { is_expected.to be_file }
    it { is_expected.to be_owned_by 'bolt' }
    it { is_expected.to be_mode 600 }
    its(:content) { is_expected.to match(/^ssh-ed25519 .* openvox-gui-bolt$/) }
  end

  describe file('/home/bolt/.bolt/tmp') do
    it { is_expected.to be_directory }
    it { is_expected.to be_mode 700 }
  end
end
