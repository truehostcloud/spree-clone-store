require 'spec_helper'

class DummyCloneStoreController < Spree::Olitt::CloneStore::CloneStoreController
end

describe Spree::Olitt::CloneStore::CloneStoreController, type: :controller do
  let!(:store) do
    Spree::Store.default.update!(name: 'My Spree Store', url: 'spreestore.example.com')
    Spree::Store.default
  end
  let(:new_store) {
    create(:store, name: 'Local Test Store', url: 'local.test', code: 'local_test')
  }

  let(:params) {
    ActionController::Parameters.new({ store: { name: 'Local Test Store', url: 'local.test', code: 'local_test',
                                                mail_from_address: 'spree@example.com' },
                                       source_store_id: store.id.to_s })
  }

  before do
    allow(controller).to receive(:params).and_return(params)
  end

  # Params

  describe '# Controller Params' do
    it 'I can receive params' do
      expect(controller.store_params).to eq(ActionController::Parameters.new({ store: { name: 'Local Test Store', url: 'local.test',
                                                                                        code: 'local_test', mail_from_address: 'spree@example.com' },
                                                                               source_store_id: store.id.to_s })
                                                                               .require(:store).permit(controller.permitted_store_attributes))
    end

    it 'I can get store params' do
      expect(controller.required_store_params).to eq(['Local Test Store', 'local.test', 'local_test', 'spree@example.com'])
    end

    it 'I can get source store id' do
      expect(controller.source_id_param).to eq(store.id.to_s)
    end

    it 'falls back to the default store when source_store_id is missing' do
      allow(params).to receive(:[]).with(:clone_store).and_return(ActionController::Parameters.new({ store: { name: 'Local Test Store', url: 'local.test', code: 'local_test', mail_from_address: 'spree@example.com' }, vendor: { email: 'vendor@example.com', password: 'secret123', password_confirmation: 'secret123' } }))
      allow(Spree::Store).to receive(:default).and_return(store)

      expect(controller.source_id_param).to eq(store.id)
    end
  end

  # Store

  describe '# Can clone store' do
    it 'I can clone a store' do
      controller.handle_clone_store
      expect(Spree::Store.all.count).to eq(2)
    end

    it 'Store was cloned correctly' do
      controller.handle_clone_store
      expect(controller.new_store).not_to be_nil
    end

    it 'Store details are correct' do
      controller.handle_clone_store
      expect(controller.new_store.code).to eq('local_test')
    end
  end

  describe '#find_clone_request' do
    it 'looks up clone requests by clone_request_id only' do
      clone_request = instance_double(Spree::Olitt::CloneStore::CloneRequest)

      expect(Spree::Olitt::CloneStore::CloneRequest).to receive(:find_by).with(id: '123').and_return(clone_request)

      expect(controller.send(:find_clone_request, '123')).to eq(clone_request)
    end
  end

  # Taxonomy

  describe '# Can Clone Taxonomy' do
    before do
      controller.old_store = store
      controller.new_store = new_store

      create(:taxonomy, store: store)
    end

    it 'My old store is not nil' do
      expect(controller.old_store).not_to be_nil
    end

    it 'My new store is not nil' do
      expect(controller.new_store).not_to be_nil
    end

    it 'My old store has a taxonomy' do
      expect(controller.old_store.taxonomies.all.count).to eq(1)
    end

    it 'I can clone a taxonomy' do
      controller.handle_clone_taxonomies
      expect(controller.new_store.taxonomies.all.count).to eq(1)
    end

    it 'My cloned taxonomy has correct details' do
      controller.handle_clone_taxonomies
      expect(controller.new_store.taxonomies.first.name).to eq(controller.old_store.taxonomies.first.name)
    end
  end

  # Taxons

  # Menus

  # Menu Items

  # Pages

  # Sections

  # Products
end
