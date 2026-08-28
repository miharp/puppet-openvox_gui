# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_gui::enc' do
  let(:params) { { api_base: ['https://console.example.com:4567'] } }
  let(:pre_condition) { "service { 'puppetserver': ensure => running }" }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:platform) do
        if os_facts[:os]['family'] == 'Debian'
          { sysconfig: '/etc/default/openvox-enc', pyyaml: 'python3-yaml' }
        else
          { sysconfig: '/etc/sysconfig/openvox-enc', pyyaml: 'python3-pyyaml' }
        end
      end

      it { is_expected.to compile.with_all_deps }

      it 'installs PyYAML before the script that imports it' do
        expect(subject).to contain_package(platform[:pyyaml])
          .with_ensure('installed')
          .that_comes_before('File[/usr/local/bin/enc.py]')
      end

      it 'installs the classifier from the module, executable, and restarts puppetserver when it changes' do
        expect(subject).to contain_file('/usr/local/bin/enc.py')
          .with(ensure: 'file', source: 'puppet:///modules/openvox_gui/enc.py', owner: 'root', mode: '0755')
          .that_notifies('Service[puppetserver]')
      end

      it "writes the console URL to the platform's environment file and nothing else" do
        expect(subject).to contain_file(platform[:sysconfig])
          .with(ensure: 'file', mode: '0644')
          .with_content(%r{^OPENVOX_GUI_API_BASE=https://console\.example\.com:4567\n\z})
          .that_notifies('Service[puppetserver]')
      end

      it 'loads the environment file from a puppetserver drop-in' do
        expect(subject).to contain_file('/etc/systemd/system/puppetserver.service.d').with_ensure('directory')
        expect(subject).to contain_file('/etc/systemd/system/puppetserver.service.d/openvox-enc.conf')
          .with_content(/^\[Service\]\nEnvironmentFile=-#{platform[:sysconfig]}\n\z/)
          .that_notifies('Exec[openvox_gui::enc daemon-reload]')
      end

      it 'reloads systemd for the drop-in, then restarts puppetserver' do
        expect(subject).to contain_exec('openvox_gui::enc daemon-reload')
          .with(command: 'systemctl daemon-reload', refreshonly: true)
          .that_notifies('Service[puppetserver]')
      end

      it 'sets node_terminus in the [server] section of puppet.conf' do
        expect(subject).to contain_ini_setting('openvox_gui::enc node_terminus')
          .with(ensure: 'present', path: '/etc/puppetlabs/puppet/puppet.conf', section: 'server', value: 'exec')
          .that_notifies('Service[puppetserver]')
      end

      it 'points external_nodes at the classifier' do
        expect(subject).to contain_ini_setting('openvox_gui::enc external_nodes')
          .with(ensure: 'present', section: 'server', setting: 'external_nodes', value: '/usr/local/bin/enc.py')
          .that_notifies('Service[puppetserver]')
      end

      context 'with two consoles' do
        let(:params) { { api_base: ['https://a.example.com:4567', 'https://b.example.com:4567'] } }

        it 'lists them comma-separated, in order' do
          expect(subject).to contain_file(platform[:sysconfig])
            .with_content(%r{^OPENVOX_GUI_API_BASE=https://a\.example\.com:4567,https://b\.example\.com:4567$})
        end
      end

      context 'with a CA file and verification off' do
        let(:params) { super().merge(ca_file: '/etc/pki/lab-ca.pem', tls_verify: false) }

        it 'passes both to the script through the environment file' do
          expect(subject).to contain_file(platform[:sysconfig])
            .with_content(%r{^OPENVOX_GUI_ENC_CA=/etc/pki/lab-ca\.pem$})
            .with_content(/^OPENVOX_GUI_ENC_TLS_VERIFY=0$/)
        end
      end

      context 'with restart_service => false and no service in the catalog' do
        let(:params) { super().merge(restart_service: false) }
        let(:pre_condition) { '' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('puppetserver') }
      end

      context 'with manage_puppet_conf => false' do
        let(:params) { super().merge(manage_puppet_conf: false) }

        it { is_expected.not_to contain_ini_setting('openvox_gui::enc node_terminus') }
        it { is_expected.not_to contain_ini_setting('openvox_gui::enc external_nodes') }
      end

      context 'with manage_pyyaml => false' do
        let(:params) { super().merge(manage_pyyaml: false) }

        it { is_expected.not_to contain_package(platform[:pyyaml]) }
      end

      context 'with ensure => absent' do
        let(:params) { super().merge(ensure: 'absent') }

        it 'removes the script, the environment file and the drop-in' do
          expect(subject).to contain_file('/usr/local/bin/enc.py').with_ensure('absent')
          expect(subject).to contain_file(platform[:sysconfig]).with_ensure('absent')
          expect(subject).to contain_file('/etc/systemd/system/puppetserver.service.d/openvox-enc.conf')
            .with_ensure('absent')
        end

        it 'takes the settings out of puppet.conf' do
          expect(subject).to contain_ini_setting('openvox_gui::enc node_terminus').with_ensure('absent')
          expect(subject).to contain_ini_setting('openvox_gui::enc external_nodes').with_ensure('absent')
        end

        it 'leaves PyYAML and the drop-in directory alone' do
          expect(subject).not_to contain_package(platform[:pyyaml])
          expect(subject).to contain_file('/etc/systemd/system/puppetserver.service.d').with_ensure('directory')
        end
      end
    end
  end
end
