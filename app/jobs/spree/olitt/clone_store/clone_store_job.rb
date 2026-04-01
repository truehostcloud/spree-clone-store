module Spree
  module Olitt
    module CloneStore
      class CloneStoreJob < ActiveJob::Base
        class CloneFailedError < StandardError; end

        queue_as :default
        retry_on CloneFailedError, wait: :polynomially_longer, attempts: 3

        def perform(old_store_id:, new_store_id:, vendor_id:)
          old_store = Spree::Store.find(old_store_id)
          new_store = Spree::Store.find(new_store_id)
          vendor = Spree::Vendor.find(vendor_id)

          runner = StoreCloneRunner.new(old_store: old_store, new_store: new_store, vendor: vendor)
          return if runner.call

          raise CloneFailedError, runner.errors.join(', ')
        end
      end
    end
  end
end