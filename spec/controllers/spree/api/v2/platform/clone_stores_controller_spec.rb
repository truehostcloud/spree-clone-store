require 'spec_helper'

describe Spree::Api::V2::Platform::CloneStoresController, type: :controller do
  routes { Spree::Core::Engine.routes }

  let!(:source_store) do
    create(:store, default: false, name: 'Source Store', url: 'source.example.com', code: 'source-store')
  end

  let!(:product) do
    create(:product, name: 'Cloned Product', slug: 'cloned-product', stores: [source_store])
  end

  let(:clone_params) do
    {
      clone_store: {
        source_store_id: source_store.id,
        store: {
          name: 'Clone Store',
          url: 'clone.example.com',
          code: 'clone-store',
          mail_from_address: 'clone@example.com'
        },
        vendor: {
          email: 'clone.vendor@example.com',
          password: 'Password123!',
          password_confirmation: 'Password123!'
        }
      }
    }
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(controller).to receive(:validate_token_client).and_return(true)
    allow(controller).to receive(:authorize_clone_store_request!).and_return(true)
    allow(controller).to receive(:authorize_superadmin_user_token!).and_return(true)
  end

  after do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'clones a store with products and returns vendor metadata' do
    post :create, params: clone_params, format: :json

    expect(response).to have_http_status(:accepted)

    payload = JSON.parse(response.body)
    clone_request = Spree::Olitt::CloneStore::CloneRequest.find(payload.fetch('clone_request_id'))

    expect(clone_request).to be_queued

    Spree::Olitt::CloneStore::CloneStoreJob.perform_now(clone_request.id)
    clone_request.reload

    expect(clone_request).to be_completed
    expect(clone_request.store).to be_present
    expect(clone_request.store.products.count).to eq(1)
    expect(clone_request.store.products.first.name).to eq('Cloned Product')

    vendor_meta = payload.fetch('meta').fetch('vendor')
    expect(vendor_meta).to include(
      'email' => 'clone.vendor@example.com',
      'next_path' => '/admin'
    )
  end

  describe 'secret API key authentication' do
    let(:api_key) { instance_double('Spree::ApiKey', id: 44, store_id: source_store.id, last_used_at: nil) }

    it 'accepts X-Spree-Api-Key without doorkeeper auth' do
      request.headers['X-Spree-Api-Key'] = 'sk_test_123'

      allow(controller).to receive(:current_store).and_return(source_store)
      allow(Spree::ApiKey).to receive(:find_by_secret_token).with('sk_test_123').and_return(api_key)
      allow(Spree::ApiKeys::MarkAsUsed).to receive(:perform_later)
      expect(controller).not_to receive(:doorkeeper_authorize!)

      controller.send(:authorize_clone_store_request!)

      expect(controller.send(:current_api_key)).to eq(api_key)
    end

    it 'renders unauthorized for an invalid X-Spree-Api-Key' do
      request.headers['X-Spree-Api-Key'] = 'sk_invalid'

      allow(controller).to receive(:current_store).and_return(source_store)
      allow(Spree::ApiKey).to receive(:find_by_secret_token).with('sk_invalid').and_return(nil)

      controller.send(:authorize_clone_store_request!)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq('error' => 'Valid secret API key required')
    end
  end

  describe '#ensure_api_key' do
    let!(:live_store) do
      create(:store, default: false, name: 'Live Store', url: 'live.example.com', code: 'live-store')
    end

    before do
      allow(Spree.current_store_finder).to receive(:new).and_return(
        instance_double(Spree.current_store_finder, execute: live_store)
      )
    end

    it 'mints a publishable key for the resolved store and returns it' do
      expect(live_store.api_keys.active.publishable.count).to eq(0)

      post :ensure_api_key, params: { url: 'live.example.com' }, format: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.dig('data', 'id')).to eq(live_store.id.to_s)
      expect(payload.dig('meta', 'status')).to eq('completed')
      expect(payload.dig('meta', 'public_api_key', 'token')).to be_present
      expect(payload.dig('meta', 'public_api_key', 'store_id')).to eq(live_store.id)
      expect(live_store.api_keys.active.publishable.count).to eq(1)
    end

    it 'is idempotent and returns the same key on a second call' do
      post :ensure_api_key, params: { url: 'live.example.com' }, format: :json
      first_token = JSON.parse(response.body).dig('meta', 'public_api_key', 'token')

      post :ensure_api_key, params: { url: 'live.example.com' }, format: :json
      second_token = JSON.parse(response.body).dig('meta', 'public_api_key', 'token')

      expect(second_token).to eq(first_token)
      expect(live_store.api_keys.active.publishable.count).to eq(1)
    end

    it 'returns not found when no store resolves for the url' do
      allow(Spree.current_store_finder).to receive(:new).and_return(
        instance_double(Spree.current_store_finder, execute: nil)
      )

      post :ensure_api_key, params: { url: 'missing.example.com' }, format: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body).dig('meta', 'status')).to eq('not_found')
    end
  end

  describe '#ensure_api_key duplicate store resolution' do
    let!(:older_store) do
      create(:store, default: false, name: 'Older Store', url: 'conflict.example.com', code: 'older-store')
    end

    let!(:newer_store) do
      create(:store, default: false, name: 'Newer Store', url: 'conflict.example.com', code: 'newer-store')
    end

    it 'mints the key on the oldest store when two stores share the same url' do
      post :ensure_api_key, params: { url: 'conflict.example.com' }, format: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.dig('data', 'id')).to eq(older_store.id.to_s)
      expect(payload.dig('meta', 'public_api_key', 'store_id')).to eq(older_store.id)
      expect(older_store.reload.api_keys.active.publishable.count).to eq(1)
      expect(newer_store.reload.api_keys.active.publishable.count).to eq(0)
    end
  end
end