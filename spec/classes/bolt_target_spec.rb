# frozen_string_literal: true

require 'spec_helper'

BOLT_PRIVATE_DIRS = %w[/home/bolt /home/bolt/.ssh /home/bolt/.bolt /home/bolt/.bolt/tmp].freeze

describe 'openvox_gui::bolt_target' do
  let(:params) do
    { authorized_keys: ['ssh-ed25519 AAAAC3one openvox-gui-bolt', 'ssh-ed25519 AAAAC3two second-console'] }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_group('bolt').with_system(true) }

      it do
        expect(subject).to contain_user('bolt')
          .with(system: true, gid: 'bolt', home: '/home/bolt', shell: '/bin/bash', managehome: true)
      end

      it 'keeps the home, .ssh, and Bolt upload directories private to the bolt user' do
        BOLT_PRIVATE_DIRS.each do |dir|
          expect(subject).to contain_file(dir).with(ensure: 'directory', owner: 'bolt', group: 'bolt', mode: '0700')
        end
      end

      it 'writes every key on its own line, readable only by the bolt user' do
        expect(subject).to contain_file('/home/bolt/.ssh/authorized_keys')
          .with_owner('bolt')
          .with_mode('0600')
          .with_content(/^ssh-ed25519 AAAAC3one openvox-gui-bolt\nssh-ed25519 AAAAC3two second-console\n\z/)
      end

      context 'with manage_user => false' do
        let(:params) { super().merge(manage_user: false) }

        it { is_expected.not_to contain_user('bolt') }
        it { is_expected.not_to contain_group('bolt') }
        it { is_expected.to compile.with_all_deps }
      end

      context 'with no keys' do
        let(:params) { { authorized_keys: [] } }

        it { is_expected.to compile.and_raise_error(/authorized_keys/) }
      end
    end
  end
end
