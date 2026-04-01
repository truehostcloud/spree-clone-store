module Spree
  module Olitt
    module CloneStore
      class TestController < CloneStoreController
        def test
          clone_request = build_clone_request
          return if clone_request.nil?

          runner = StoreCloneRunner.new(
            old_store: clone_request.source_store,
            new_store: clone_request.store,
            vendor: clone_request.vendor
          )

          if runner.call
            clone_request.mark_completed!
            render json: serialize_clone_request(clone_request), status: :ok
          else
            clone_request.mark_failed!(runner.errors.join(', '))
            clone_request.cleanup_failed_clone!
            render json: { errors: runner.errors }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
