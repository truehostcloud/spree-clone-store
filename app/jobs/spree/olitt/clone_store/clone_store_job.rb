module Spree
  module Olitt
    module CloneStore
      class CloneStoreJob < ::ApplicationJob
        class CloneFailedError < StandardError; end

        MAX_ATTEMPTS = 3

        queue_as :default
        retry_on CloneFailedError, wait: :polynomially_longer, attempts: MAX_ATTEMPTS do |job, error|
          clone_request = CloneRequest.find_by(id: job.arguments.first)
          if clone_request.present?
            clone_request.mark_failed!(error.message)
            clone_request.cleanup_failed_clone!
          end
        end

        def perform(clone_request_id)
          clone_request = CloneRequest.find(clone_request_id)
          clone_request.mark_running!

          provisioner = CloneRequestProvisioner.new(clone_request: clone_request)
          unless provisioner.call
            raise CloneFailedError, provisioner.errors.join(', ')
          end

          clone_request.reload

          runner = StoreCloneRunner.new(
            old_store: clone_request.source_store,
            new_store: clone_request.store,
            vendor: clone_request.vendor
          )
          return clone_request.mark_completed! if runner.call

          raise CloneFailedError, runner.errors.join(', ')
        rescue LoadError => e
          clone_request&.mark_failed!(e.message)
          clone_request&.cleanup_failed_clone!
          raise e
        rescue StandardError => e
          raise e if e.is_a?(CloneFailedError)

          raise CloneFailedError, e.message
        end
      end
    end
  end
end