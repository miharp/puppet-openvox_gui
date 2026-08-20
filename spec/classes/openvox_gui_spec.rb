# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_gui' do
  let(:params) do
    {
      version: '3.10.6',
      admin_password: sensitive('supersecret'),
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:install_conf) do
        content = catalogue.resource('file', '/opt/openvox-gui-src/install.conf')[:content]
        content.respond_to?(:unwrap) ? content.unwrap : content
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('openvox_gui::install') }
      it { is_expected.to contain_class('openvox_gui::config') }
      it { is_expected.to contain_class('openvox_gui::service') }

      it { is_expected.to contain_package('git') }
      it { is_expected.to contain_package('nodejs') }
      it { is_expected.to contain_package('npm') }
      it { is_expected.to contain_package('diffutils') }

      it 'installs python3-venv only where python3 lacks venv' do
        if os_facts[:os]['family'] == 'Debian'
          expect(subject).to contain_package('python3-venv')
        else
          expect(subject).not_to contain_package('python3-venv')
        end
      end

      it { is_expected.to contain_group('puppet').with_system(true) }
      it { is_expected.to contain_user('puppet').with_gid('puppet').with_system(true) }

      context 'with manage_service_user => false' do
        let(:params) { super().merge(manage_service_user: false) }

        it { is_expected.not_to contain_user('puppet') }
        it { is_expected.to compile.with_all_deps }
      end

      it do
        expect(subject).to contain_vcsrepo('/opt/openvox-gui-src')
          .with_source('https://github.com/cvquesty/openvox-gui.git')
          .with_revision('v3.10.6')
      end

      it do
        expect(subject).to contain_exec('openvox_gui build frontend')
          .with_command('/bin/bash /opt/openvox-gui-src/build-frontend.sh')
          .with_unless(%r{cmp -s /opt/openvox-gui-src/VERSION /opt/openvox-gui-src/frontend/.built-version})
      end

      it do
        expect(subject).to contain_file('/opt/openvox-gui-src/install.conf')
          .with_owner('root')
          .with_group('root')
          .with_mode('0600')
          .with_show_diff(false)
      end

      it 'renders the managed installer settings' do
        expect(install_conf).to include('INSTALL_DIR=/opt/openvox-gui', 'APP_PORT=4567',
                                        'ADMIN_USERNAME=admin', 'ADMIN_PASSWORD=supersecret',
                                        'SSL_ENABLED=true')
      end

      it 'keeps the build, firewall, and mirror out of the installer' do
        expect(install_conf).to include('BUILD_FRONTEND=false', 'INSTALL_NODEJS=false',
                                        'CONFIGURE_FIREWALL=false', 'CONFIGURE_PKG_REPO=false')
      end

      it 'defaults the TLS certificate to the node certname' do
        expect(install_conf).to match(%r{^SSL_CERT_PATH=/etc/puppetlabs/puppet/ssl/certs/.+\.pem$})
        expect(install_conf).to match(%r{^SSL_KEY_PATH=/etc/puppetlabs/puppet/ssl/private_keys/.+\.pem$})
      end

      it 'only configures SELinux on the RedHat family' do
        expected = (os_facts[:os]['family'] == 'RedHat') ? 'true' : 'false'
        expect(install_conf).to include("CONFIGURE_SELINUX=#{expected}")
      end

      it do
        expect(subject).to contain_exec('openvox_gui run installer')
          .with_cwd('/opt/openvox-gui-src')
          .with_unless(%r{cmp -s install\.conf /opt/openvox-gui/\.puppet-install\.conf})
      end

      it 'verifies a failed installer with a scheme-matched health probe' do
        expect(subject).to contain_exec('openvox_gui run installer')
          .with_command(%r{curl -skf https://127\.0\.0\.1:4567/health})
      end

      it { is_expected.to contain_service('openvox-gui').with_ensure('running').with_enable(true) }

      context 'with ssl_enabled => false' do
        let(:params) { super().merge(ssl_enabled: false) }

        it { expect(install_conf).to include('SSL_ENABLED=false') }
        it { expect(install_conf).not_to include('SSL_CERT_PATH') }

        it 'probes plain http' do
          expect(subject).to contain_exec('openvox_gui run installer')
            .with_command(%r{curl -skf http://127\.0\.0\.1:4567/health})
        end
      end

      context 'with auth_backend => none' do
        let(:params) { super().merge(auth_backend: 'none') }

        it { expect(install_conf).to include('AUTH_BACKEND=none') }
        it { expect(install_conf).not_to include('ADMIN_PASSWORD') }
      end

      context 'with extra_settings' do
        let(:params) do
          super().merge(extra_settings: { 'OPENVOX_GUI_DB_BACKEND' => 'postgresql', 'APP_DEBUG' => true })
        end

        it { expect(install_conf).to include('OPENVOX_GUI_DB_BACKEND=postgresql', 'APP_DEBUG=true') }
      end

      context 'with a revision override' do
        let(:params) { super().merge(revision: 'main') }

        it { is_expected.to contain_vcsrepo('/opt/openvox-gui-src').with_revision('main') }
      end

      context 'with manage_dependencies => false' do
        let(:params) { super().merge(manage_dependencies: false) }

        it { is_expected.not_to contain_package('nodejs') }
        it { is_expected.to compile.with_all_deps }
      end

      context 'with service_manage => false' do
        let(:params) { super().merge(service_manage: false) }

        it { is_expected.not_to contain_service('openvox-gui') }
      end
    end
  end
end
