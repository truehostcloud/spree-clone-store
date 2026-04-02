module Spree
  module Olitt
    module CloneStore
      class CloneRequestPresenter
        def initialize(clone_request:, serializer:)
          @clone_request = clone_request
          @serializer = serializer
        end

        def as_json
          payload = store_payload
          payload = { data: payload } unless payload.is_a?(Hash)
          payload[:clone_request_id] = @clone_request.id
          payload[:job_id] = @clone_request.job_id if @clone_request.job_id.present?
          payload[:status] = @clone_request.status
          payload[:meta] = payload.fetch(:meta, {}).merge(metadata)
          payload
        end

        private

        def store_payload
          return @clone_request.fallback_store_payload if @clone_request.store.blank?

          serialized = @serializer.call(@clone_request.store)
          serialized.is_a?(Hash) ? serialized : { data: serialized }
        rescue StandardError
          @clone_request.fallback_store_payload
        end

        def metadata
          {
            clone_request_id: @clone_request.id,
            status: @clone_request.status,
            job_id: @clone_request.job_id,
            clone_job_id: @clone_request.job_id,
            source_store_id: @clone_request.source_store_id,
            cloned_store_id: @clone_request.store_id,
            queue_name: @clone_request.queue_name,
            queued_at: @clone_request.enqueued_at,
            started_at: @clone_request.started_at,
            finished_at: @clone_request.finished_at,
            error: @clone_request.error_message
          }.compact
        end
      end
    end
  end
end