module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ShippingCategoriesDuplicator < BaseDuplicator
          attr_reader :shipping_categories_cache

          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @shipping_categories_cache = {}
          end

          def handle_clone_shipping_categories
            source_shipping_categories.each do |shipping_category|
              clone_shipping_category(shipping_category)
            rescue StandardError => e
              record_errors([e.message], context: "shipping category #{shipping_category.id}")
            end
          end

          private

          def source_shipping_categories
            categories_from_products = @old_store.products.includes(:shipping_category).map(&:shipping_category)
            categories_from_methods = if source_vendor.present?
                                        source_vendor.shipping_methods.includes(:shipping_categories).flat_map(&:shipping_categories)
                                      else
                                        []
                                      end

            (categories_from_products + categories_from_methods).compact.uniq(&:id)
          end

          def source_vendor
            return @source_vendor if defined?(@source_vendor)

            @source_vendor = @old_store.respond_to?(:vendor) ? @old_store.vendor : nil
          end

          def clone_shipping_category(shipping_category)
            new_shipping_category = find_or_initialize_shipping_category(shipping_category: shipping_category)
            assign_vendor(model_instance: new_shipping_category, vendor: @vendor)
            new_shipping_category.name = unique_shipping_category_name(shipping_category: shipping_category, new_shipping_category: new_shipping_category)
            saved = save_model(model_instance: new_shipping_category, context: "shipping category #{shipping_category.id}")
            return unless saved

            cache_shipping_category(old_shipping_category: shipping_category, new_shipping_category: new_shipping_category)
          end

          def find_or_initialize_shipping_category(shipping_category:)
            vendor_shipping_categories.find_by(name: shipping_category.name) || Spree::ShippingCategory.new
          end

          def cache_shipping_category(old_shipping_category:, new_shipping_category:)
            @shipping_categories_cache[old_shipping_category.id] = [new_shipping_category]
            @shipping_categories_cache[old_shipping_category.name] = [new_shipping_category]
          end

          def unique_shipping_category_name(shipping_category:, new_shipping_category:)
            unique_value(base_value: shipping_category.name) do |candidate|
              vendor_shipping_categories.where.not(id: new_shipping_category.id).where(name: candidate).exists?
            end
          end

          def vendor_shipping_categories
            Spree::ShippingCategory.where(vendor_id: @vendor.id)
          end
        end
      end
    end
  end
end