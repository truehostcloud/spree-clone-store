module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ProductsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers
          include Spree::Olitt::CloneStore::ProductHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = Spree::Store.includes(:taxonomies).find_by(id: new_store.id)
          end

          def handle_clone_products
            @new_store = Spree::Store.includes(:taxons).find_by(id: @new_store.id)
            new_products = @old_store.products.map { |product| clone_product(old_product: product) }

            return false unless save_models(new_products)

            true
          end

          def clone_product(old_product:)
            old_product.dup.tap do |new_product|
              new_product.taxons = old_product.taxons.map { |old_taxon| find_taxon(old_taxon: old_taxon) }
              new_product.stores = [@new_store]
              new_product.created_at = nil
              new_product.deleted_at = nil
              new_product.updated_at = nil
              new_product.product_properties = reset_properties(product: old_product)
              new_product.master = duplicate_master_variant(product: old_product)
              new_product.variants = old_product.variants.map { |variant| duplicate_variant(variant: variant) }
            end
          end

          def find_taxon(old_taxon:)
            @new_store.taxons.find { |new_taxon| new_taxon.permalink == old_taxon.permalink }
          end
        end
      end
    end
  end
end
