module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ProductsDuplicator < BaseDuplicator
          attr_reader :products_cache

          include Spree::Olitt::CloneStore::ProductHelpers

          def initialize(old_store:, new_store:, vendor:, taxon_cache:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @taxon_cache = taxon_cache

            @products_cache = {}
          end

          def handle_clone_products
            old_products = @old_store.products.includes(:product_properties, :taxons, :variants, master: %i[images default_price])
            old_products.each do |old_product|
              break if errors_are_present?

              save_product(old_product: old_product)
            end
          end

          def save_product(old_product:)
            new_product = old_product.dup
            new_product.stores = [@new_store]
            new_product = reset_timestamps(product: new_product)
            new_product.taxons = get_new_taxons(old_product: old_product)
            new_product.vendor_id = @vendor.id
            new_product.variants = get_new_variants(old_product: old_product)
            new_product.master = duplicate_master_variant(product: old_product, vendor_id: @vendor.id, code: @new_store.code)
            new_product.product_properties = reset_properties(product: old_product)
            save_model(model_instance: new_product)
            return if errors_are_present?

            @products_cache[old_product.slug] = [new_product]
          end

          def get_new_taxons(old_product:)
            old_product.taxons.map { |old_taxon| @taxon_cache[old_taxon.permalink]&.first }.compact
          end

          def get_new_variants(old_product:)
            old_product.variants.map { |variant| duplicate_variant(variant: variant, vendor_id: @vendor.id, code: @new_store.code) }
          end

          def reset_timestamps(product:)
            product.created_at = nil
            product.deleted_at = nil
            product.updated_at = nil
            product
          end
        end
      end
    end
  end
end
