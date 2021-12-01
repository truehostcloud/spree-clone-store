module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class LinkedResourceDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store
          end

          def get_new_linked_taxon(old_taxon:)
            if old_taxon.instance_of?('Spree::Taxon'.constantize)
              new_taxon = @new_store.taxons.find_by(permalink: old_taxon.permalink)
              return new_taxon.id
            end
            nil
          end

          def get_new_linked_product(old_product:)
            if old_product.instance_of?('Spree::Product'.constantize)
              new_product = @new_store.products.find_by(slug: old_product.slug)
              return new_product.id
            end
            nil
          end

          def get_new_linked_page(old_page:)
            if old_page.instance_of?('Spree::CmsPage'.constantize)
              new_page = @new_store.cms_pages.find_by(slug: old_page.slug)
              return new_page.id
            end
            nil
          end

          def reset_section_resource(section:)
            section.linked_resource_id = nil
            section.linked_resource_type = nil
            section
          end
        end
      end
    end
  end
end
