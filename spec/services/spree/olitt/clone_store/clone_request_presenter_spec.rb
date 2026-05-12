require 'spec_helper'

describe Spree::Olitt::CloneStore::CloneRequestPresenter do
  describe '#as_json' do
    it 'returns data, clone_request_id, status, and meta with extra fields' do
      public_api_key = instance_double(
        Spree::ApiKey,
        id: 55,
        name: 'Storefront key',
        key_type: 'publishable',
        token: 'pk_test_123456',
        store_id: 10
      )

      clone_request = instance_double(
        Spree::Olitt::CloneStore::CloneRequest,
        id: 123,
        job_id: 'job-123',
        status: 'queued',
        source_store_id: 9,
        store_id: 10,
        queue_name: 'default',
        enqueued_at: '2026-04-21T07:28:00.952Z',
        started_at: nil,
        finished_at: nil,
        error_message: nil,
        vendor_id: 11,
        vendor_email: 'vendor@example.com',
        vendor: instance_double(Spree::Vendor, slug: 'vendor-slug'),
        admin_user: instance_double(Spree.admin_user_class, id: 77),
        store: instance_double(Spree::Store, api_keys: instance_double(ActiveRecord::Relation)),
        fallback_store_payload: { data: { id: '10', type: 'store', attributes: { name: 'Clone' } } }
      )

      allow(clone_request.store.api_keys).to receive_message_chain(:active, :publishable, :order, :first).and_return(public_api_key)

      presenter = described_class.new(clone_request: clone_request, serializer: ->(_store) { raise 'unused' })
      payload = presenter.as_json

      expect(payload[:data]).to eq({ id: '10', type: 'store', attributes: { name: 'Clone' } })
      expect(payload[:clone_request_id]).to eq(123)
      expect(payload[:status]).to eq('queued')
      expect(payload[:meta]).to eq({
        clone_request_id: 123,
        status: 'queued',
        source_store_id: 9,
        queue_name: 'default',
        queued_at: '2026-04-21T07:28:00.952Z',
        vendor: {
          vendor_id: 11,
          vendor_slug: 'vendor-slug',
          admin_user_id: 77,
          email: 'vendor@example.com',
          next_path: '/admin'
        },
        public_api_key: {
          id: 55,
          name: 'Storefront key',
          key_type: 'publishable',
          token: 'pk_test_123456',
          store_id: 10
        }
      })
    end
  end
end