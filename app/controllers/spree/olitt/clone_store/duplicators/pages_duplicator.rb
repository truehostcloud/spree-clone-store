module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class PagesDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store
          end

          def handle_clone_pages
            pages = @old_store.cms_pages
            cloned_pages = @new_store.cms_pages.build(get_model_hash(pages))
            return false unless save_models(cloned_pages)

            true
          end
        end
      end
    end
  end
end
