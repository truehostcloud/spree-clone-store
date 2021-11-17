require 'spec_helper'

class DummyCloneStoreController < Spree::Olitt::CloneStore::CloneStoreController
end

describe Spree::Olitt::CloneStore::CloneStoreController, type: :controller do
  let(:dummy_controller) { ApiV2DummyController.new }
  let(:store) { Spree::Store.default }

  describe '#handle_clone_store' do
    let(:params) { {} }

    before do
      allow(dummy_controller).to receive(:params).and_return(params)
    end

    it 'Clone Store' do
      expect(dummy_controller.send(:finder_params)).to eq(params.merge)
    end
  end
end
