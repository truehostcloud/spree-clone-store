module Spree
  module Olitt
    module CloneStore
      class CloneStoreJob < ::ApplicationJob
        queue_as :default

        def perform(clone_request_id)
          clone_request = CloneRequest.find(clone_request_id)
          clone_request.mark_running!

          provisioner = CloneRequestProvisioner.new(clone_request: clone_request)
          unless provisioner.call
            fail_clone_request!(clone_request, provisioner.errors)
            return
          end

          clone_request.reload
          run_clone_content(clone_request)
          clone_request.mark_completed!
        rescue StandardError => e
          fail_clone_request!(clone_request, [e.message])
        end

        private

        def run_clone_content(clone_request)
          runner = StoreCloneRunner.new(
            old_store: clone_request.source_store,
            new_store: clone_request.store,
            vendor: clone_request.vendor
          )

          return if runner.call

          log_content_clone_failure(clone_request, runner.errors)
        rescue StandardError => e
          log_content_clone_failure(clone_request, [e.message])
        end

        def fail_clone_request!(clone_request, errors)
          return if clone_request.blank?

          error_message = Array(errors).flatten.compact.join(', ')
          clone_request.mark_failed!(error_message)
          clone_request.cleanup_failed_clone!
        end

        def log_content_clone_failure(clone_request, errors)
          error_message = Array(errors).flatten.compact.join(', ')
          Rails.logger.error(
            "[spree_clone_store] content clone failed for clone_request_id=#{clone_request.id}: #{error_message}"
          )
        end
      end
    end
  end
end