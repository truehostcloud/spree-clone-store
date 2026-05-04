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
end