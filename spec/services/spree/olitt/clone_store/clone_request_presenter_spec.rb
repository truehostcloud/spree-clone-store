require 'spec_helper'

describe Spree::Olitt::CloneStore::CloneRequestPresenter do
  describe '#as_json' do
    it 'includes clone_request_id in the response payload' do
      clone_request = instance_double(
        Spree::Olitt::CloneStore::CloneRequest,
        id: 123,
        job_id: 'job-123',
        status: 'queued',
        source_store_id: 9,
        store_id: 10,
        queue_name: 'default',
        enqueued_at: nil,
        started_at: nil,
        finished_at: nil,
        error_message: nil,
        store: nil,
        fallback_store_payload: { data: { id: '10', type: 'store', attributes: { name: 'Clone' } } }
      )

      presenter = described_class.new(clone_request: clone_request, serializer: ->(_store) { raise 'unused' })
      payload = presenter.as_json

      expect(payload[:clone_request_id]).to eq(123)
      expect(payload.dig(:meta, :clone_request_id)).to eq(123)
    end
  end
end