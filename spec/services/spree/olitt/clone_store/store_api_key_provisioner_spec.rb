require 'spec_helper'

describe Spree::Olitt::CloneStore::StoreApiKeyProvisioner do
  describe '.call' do
    let(:store) do
      create(:store, default: false, url: 'shop.example.com', code: 'shop-store')
    end

    it 'creates a publishable api key when the store has none' do
      expect(store.api_keys.active.publishable.count).to eq(0)

      api_key = described_class.call(store)

      expect(api_key).to be_present
      expect(api_key.key_type).to eq('publishable')
      expect(api_key.store_id).to eq(store.id)
      expect(store.api_keys.active.publishable.count).to eq(1)
    end

    it 'returns the existing key instead of creating a second one' do
      first_key = described_class.call(store)
      second_key = described_class.call(store)

      expect(second_key.id).to eq(first_key.id)
      expect(store.api_keys.active.publishable.count).to eq(1)
    end
  end
end
