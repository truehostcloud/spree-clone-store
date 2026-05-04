module Spree
  module Olitt
    module CloneStore
      class CloneRequestPresenter
        def initialize(clone_request:, serializer:)
          @clone_request = clone_request
          @serializer = serializer
        end

        def as_json
          {
            data: resource_payload,
            clone_request_id: @clone_request.id,
            status: @clone_request.status,
            meta: metadata
          }
        end

        private

        def resource_payload
          if @clone_request.store.blank?
            fallback_payload = @clone_request.fallback_store_payload
            return fallback_payload.is_a?(Hash) ? fallback_payload.fetch(:data, fallback_payload['data']) : fallback_payload
          end

          serialized = @serializer.call(@clone_request.store)
          serialized.is_a?(Hash) ? serialized.fetch(:data, serialized['data']) : serialized
        rescue StandardError
          fallback_payload = @clone_request.fallback_store_payload
          fallback_payload.is_a?(Hash) ? fallback_payload.fetch(:data, fallback_payload['data']) : fallback_payload
        end

        def metadata
          {
            clone_request_id: @clone_request.id,
            status: @clone_request.status,
            source_store_id: @clone_request.source_store_id,
            queue_name: @clone_request.queue_name,
            queued_at: @clone_request.enqueued_at,
            vendor: vendor_metadata
          }
        end

        def vendor_metadata
          {
            vendor_id: @clone_request.vendor_id,
            vendor_slug: @clone_request.vendor&.slug,
            admin_user_id: @clone_request.admin_user&.id,
            email: @clone_request.vendor_email,
            next_path: admin_dashboard_path
          }
        end

        def admin_dashboard_path
          '/admin'
        end
      end
    end
  end
end