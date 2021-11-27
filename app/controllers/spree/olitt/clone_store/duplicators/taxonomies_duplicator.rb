module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class TaxonomiesDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store
          end

          def handle_clone_taxonomies
            taxonomies = @old_store.taxonomies
            cloned_taxonomies = @new_store.taxonomies.build(get_model_hash(taxonomies))
            return false unless save_models(cloned_taxonomies)

            true
          end
        end
      end
    end
  end
end
