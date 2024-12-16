module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class LinkedResourceDuplicator
          attr_accessor :taxons_cache, :pages_cache, :products_cache

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store

            @taxons_cache = {}
            @pages_cache = {}
            @products_cache = {}

            @old_taxons = nil
            @old_pages = nil
            @old_products = nil
          end

          def assign_linked_resource(model:)
            return assign_taxon(model: model) if model.linked_resource_type == 'Spree::Taxon'

            return assign_product(model: model) if model.linked_resource_type == 'Spree::Product'

            return assign_page(model: model) if model.linked_resource_type == 'Spree::CmsPage'

            model
          end

          private

          def assign_taxon(model:)
            @old_taxons = @old_store.taxons.group_by(&:id) if @old_taxons.nil?
            old_taxon = @old_taxons[model.linked_resource_id]&.first
            return model unless old_taxon

            new_taxon = @taxons_cache[old_taxon.permalink]&.first
            return model unless new_taxon

            model.linked_resource_id = new_taxon.id
            model
          end

          def assign_product(model:)
            @old_products = @old_store.products.group_by(&:id) if @old_products.nil?
            old_product = @old_products[model.linked_resource_id].first
            new_product = @products_cache[old_product.slug].first
            model.linked_resource_id = new_product.id
            model
          end

          def assign_page(model:)
            @old_pages = @old_store.cms_pages.group_by(&:id) if @old_pages.nil?
            old_page = @old_pages[model.linked_resource_id].first
            new_page = @pages_cache[old_page.slug].first
            model.linked_resource_id = new_page.id
            model
          end
        end
      end
    end
  end
end
