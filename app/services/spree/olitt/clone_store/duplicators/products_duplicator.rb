module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ProductsDuplicator < BaseDuplicator
          attr_reader :products_cache, :variants_cache

          include Spree::Olitt::CloneStore::ProductHelpers

          def initialize(old_store:, new_store:, vendor:, taxon_cache:, shipping_category_cache: {}, option_type_cache: {}, option_value_cache: {})
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @taxon_cache = taxon_cache
            @shipping_category_cache = shipping_category_cache
            @option_type_cache = option_type_cache
            @option_value_cache = option_value_cache
            @limit = ENV['PRODUCTS_CLONE_LIMIT']&.to_i || 20

            @products_cache = {}
            @variants_cache = {}
          end

          def handle_clone_products
            old_products = @old_store.products.includes(
              :shipping_category,
              :tax_category,
              :product_properties,
              :taxons,
              { product_option_types: :option_type },
              { variants: [:images, :prices, :tax_category, { option_values: :option_type }] },
              master: %i[images prices default_price tax_category]
            ).limit(@limit)
            old_products.each do |old_product|
              save_product(old_product: old_product)
            rescue StandardError => e
              record_errors([e.message], context: "product #{old_product.id}")
            end
          end

          def save_product(old_product:)
            new_product = old_product.dup
            new_product.stores = [@new_store]
            new_product = reset_timestamps(product: new_product)
            new_product.slug = build_cloned_slug(old_product: old_product)
            new_product.taxons = get_new_taxons(old_product: old_product)
            new_product.tax_category = resolve_tax_category(old_product.tax_category)
            new_product.shipping_category = get_new_shipping_category(old_product: old_product)
            new_product.vendor_id = @vendor.id
            new_product.product_option_types = reset_product_option_types(product: old_product)
            new_product.variants = get_new_variants(old_product: old_product)
            new_product.master = duplicate_master_variant(
              product: old_product,
              vendor_id: @vendor.id,
              code: @new_store.code,
              tax_category: resolve_tax_category(old_product.master&.tax_category)
            )
            new_product.product_properties = reset_properties(product: old_product)
            saved = save_model(model_instance: new_product, context: "product #{old_product.id}")
            return unless saved

            @products_cache[old_product.slug] = [new_product]
            cache_variants(old_product: old_product, new_product: new_product)
          end

          def get_new_taxons(old_product:)
            old_product.taxons.map { |old_taxon| @taxon_cache[old_taxon.permalink]&.first }.compact
          end

          def get_new_shipping_category(old_product:)
            old_shipping_category = old_product.shipping_category
            return if old_shipping_category.blank?

            @shipping_category_cache[old_shipping_category.id]&.first ||
              @shipping_category_cache[old_shipping_category.name]&.first ||
              old_shipping_category
          end

          def get_new_variants(old_product:)
            old_product.variants.filter_map do |variant|
              new_variant = duplicate_variant(
                variant: variant,
                vendor_id: @vendor.id,
                code: @new_store.code,
                option_values: get_new_option_values(variant: variant),
                tax_category: resolve_tax_category(variant.tax_category)
              )
              next new_variant if new_variant.present?

              Rails.logger.warn(
                "[spree_clone_store] Skipping variant #{variant.id} for product #{old_product.id} because it has no option values"
              )
              nil
            end
          end

          def get_new_option_values(variant:)
            variant.option_values.map { |option_value| @option_value_cache[option_value.id]&.first }.compact
          end

          def reset_product_option_types(product:)
            product.product_option_types.filter_map do |product_option_type|
              option_type = @option_type_cache[product_option_type.option_type_id]&.first
              next if option_type.blank?

              new_product_option_type = product_option_type.dup
              new_product_option_type.option_type = option_type
              new_product_option_type.created_at = nil
              new_product_option_type.updated_at = nil
              new_product_option_type
            end
          end

          def cache_variants(old_product:, new_product:)
            @variants_cache[old_product.master.id] = [new_product.master] if old_product.master.present? && new_product.master.present?

            old_product.variants.each_with_index do |old_variant, index|
              new_variant = new_product.variants[index]
              next if new_variant.blank?

              @variants_cache[old_variant.id] = [new_variant]
            end
          end

          def reset_timestamps(product:)
            product.created_at = nil
            product.deleted_at = nil
            product.updated_at = nil
            product
          end

          def build_cloned_slug(old_product:)
            return @new_store.code if old_product.slug.blank?

            "#{old_product.slug}-#{@new_store.code}"
          end

          def resolve_tax_category(old_tax_category)
            return if old_tax_category.blank?

            @tax_category_cache ||= {}
            @tax_category_cache[old_tax_category.id] ||= begin
              Spree::TaxCategory.find_by(id: old_tax_category.id) ||
                Spree::TaxCategory.find_by(name: old_tax_category.name) ||
                find_tax_category_by_tax_code(old_tax_category: old_tax_category) ||
                default_tax_category(old_tax_category: old_tax_category) ||
                old_tax_category
            end
          end

          def find_tax_category_by_tax_code(old_tax_category:)
            return if old_tax_category.tax_code.blank?

            Spree::TaxCategory.find_by(tax_code: old_tax_category.tax_code)
          end

          def default_tax_category(old_tax_category:)
            return unless old_tax_category.respond_to?(:is_default?) && old_tax_category.is_default?

            Spree::TaxCategory.default
          end
        end
      end
    end
  end
end
