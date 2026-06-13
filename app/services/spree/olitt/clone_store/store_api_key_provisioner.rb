module Spree
  module Olitt
    module CloneStore
      class StoreApiKeyProvisioner
        def self.call(store)
          new(store).call
        end

        def initialize(store)
          @store = store
        end

        def call
          return nil unless @store.respond_to?(:api_keys)

          @store.api_keys.active.publishable.first ||
            @store.api_keys.create!(name: 'Storefront key', key_type: 'publishable')
        rescue ActiveRecord::RecordNotUnique
          @store.api_keys.active.publishable.first
        end
      end
    end
  end
end
