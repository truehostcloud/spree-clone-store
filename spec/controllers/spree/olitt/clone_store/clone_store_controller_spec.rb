require 'spec_helper'

class DummyCloneStoreController < Spree::Olitt::CloneStore::CloneStoreController
end

# describe Spree::Olitt::CloneStore::CloneStoreController, type: :controller do
  let(:store) { Spree::Store.default }

  describe '#handle_clone_store' do
    let(:params) { {} }

    before do
      allow(controller).to receive(:params).and_return(params)
      allow(controller).to receive(:old_store).and_return(params)
    end

    it 'Clone Store' do
      controller.send(:handle_clone_store)
      expect().to eq(params.merge)
    end
  end

  describe '#handle_clone_taxonomies' do
    let(:params) { {} }

    before do
      allow(controller).to receive(:old_store).and_return(params)
      allow(controller).to receive(:new_store).and_return(params)
    end

    it 'Clone Taxonomy' do
      controller.send(:handle_clone_store)
      expect().to eq(params.merge)
    end
  end
end