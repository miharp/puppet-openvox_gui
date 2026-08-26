# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_gui_bolt_pubkey', type: :fact do
  subject(:fact) { Facter.fact(:openvox_gui_bolt_pubkey) }

  let(:pubkey) { '/etc/puppetlabs/bolt/id_bolt.pub' }

  before do
    Facter.clear
    allow(File).to receive(:readable?).and_call_original
    allow(File).to receive(:read).and_call_original
  end

  context 'when the console has generated its orchestration key' do
    before do
      allow(File).to receive(:readable?).with(pubkey).and_return(true)
      allow(File).to receive(:read).with(pubkey).and_return("ssh-ed25519 AAAAC3test openvox-gui-bolt\n")
    end

    it { expect(fact.value).to eq('ssh-ed25519 AAAAC3test openvox-gui-bolt') }
  end

  context 'when the key file is empty' do
    before do
      allow(File).to receive(:readable?).with(pubkey).and_return(true)
      allow(File).to receive(:read).with(pubkey).and_return("\n")
    end

    it { expect(fact.value).to be_nil }
  end

  context 'when there is no key (not a console)' do
    before { allow(File).to receive(:readable?).with(pubkey).and_return(false) }

    it { expect(fact.value).to be_nil }
  end
end
