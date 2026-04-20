module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ShippingMethodsDuplicator < BaseDuplicator
          def initialize(old_store:, vendor:, new_store:, shipping_categories_cache: {}, zone_resolver: nil)
            super()
            @old_store = old_store
            @vendor = vendor
            @new_store = new_store
            @shipping_categories_cache = shipping_categories_cache
            @zone_resolver = zone_resolver || ZoneResolver.new
          end

          def duplicate
            source_shipping_methods.find_each do |shipping_method|
              clone_shipping_method(shipping_method)
            rescue StandardError => e
              record_errors([e.message], context: "shipping method #{shipping_method.id}")
            end
          end

          private

          def source_shipping_methods
            return fallback_shipping_methods if source_vendor.blank?

            source_vendor.shipping_methods.includes(:shipping_categories, :zones, :calculator)
          end

          def source_vendor
            return @source_vendor if defined?(@source_vendor)

            @source_vendor = @old_store.respond_to?(:vendor) ? @old_store.vendor : nil
          end

          def fallback_shipping_methods
            ids = ENV['CLONE_SHIPPING_METHODS_IDS'].to_s.split(',').map(&:strip).reject(&:blank?)
            Spree::ShippingMethod.where(id: ids).includes(:shipping_categories, :zones, :calculator)
          end

          def clone_shipping_method(shipping_method)
            new_shipping_method = find_or_initialize_shipping_method(shipping_method: shipping_method)
            assign_vendor(model_instance: new_shipping_method, vendor: @vendor)
            assign_shipping_method_attributes(new_shipping_method: new_shipping_method, shipping_method: shipping_method)
            new_shipping_method.shipping_categories = remapped_shipping_categories(shipping_method: shipping_method)
            new_shipping_method.zones = resolved_zones(shipping_method: shipping_method)
            new_shipping_method.calculator = duplicate_calculator(shipping_method.calculator)
            save_model(model_instance: new_shipping_method, context: "shipping method #{shipping_method.id}")
          end

          def find_or_initialize_shipping_method(shipping_method:)
            @vendor.shipping_methods.find_by(name: shipping_method_name(shipping_method: shipping_method)) || Spree::ShippingMethod.new
          end

          def assign_shipping_method_attributes(new_shipping_method:, shipping_method:)
            new_shipping_method.name = shipping_method_name(shipping_method: shipping_method)
            new_shipping_method.display_on = shipping_method.display_on
            new_shipping_method.tracking_url = shipping_method.tracking_url
            new_shipping_method.admin_name = shipping_method.admin_name
            new_shipping_method.tax_category = shipping_method.tax_category
            new_shipping_method.code = unique_shipping_method_code(shipping_method: shipping_method, new_shipping_method: new_shipping_method)
            new_shipping_method.public_metadata = shipping_method.public_metadata if new_shipping_method.respond_to?(:public_metadata=)
            new_shipping_method.private_metadata = shipping_method.private_metadata if new_shipping_method.respond_to?(:private_metadata=)
            new_shipping_method.estimated_transit_business_days_min = shipping_method.estimated_transit_business_days_min
            new_shipping_method.estimated_transit_business_days_max = shipping_method.estimated_transit_business_days_max
            new_shipping_method.external_id = shipping_method.external_id if new_shipping_method.respond_to?(:external_id=)
            new_shipping_method.deleted_at = nil if new_shipping_method.respond_to?(:deleted_at=)
          end

          def shipping_method_name(shipping_method:)
            "#{shipping_method.name} - #{@new_store.name}"
          end

          def remapped_shipping_categories(shipping_method:)
            shipping_method.shipping_categories.filter_map do |shipping_category|
              @shipping_categories_cache[shipping_category.id]&.first ||
                @shipping_categories_cache[shipping_category.name]&.first ||
                shipping_category
            end
          end

          def resolved_zones(shipping_method:)
            shipping_method.zones.filter_map { |zone| @zone_resolver.resolve(zone) }
          end

          def unique_shipping_method_code(shipping_method:, new_shipping_method:)
            base_code = shipping_method.code.presence || shipping_method.name.to_s.parameterize(separator: '_')

            unique_value(base_value: base_code, separator: '_', max_length: 255) do |candidate|
              @vendor.shipping_methods.where.not(id: new_shipping_method.id).where(code: candidate).exists?
            end
          end

          def duplicate_calculator(calculator)
            return if calculator.blank?

            new_calculator = calculator.dup
            new_calculator.created_at = nil if new_calculator.respond_to?(:created_at=)
            new_calculator.updated_at = nil if new_calculator.respond_to?(:updated_at=)
            new_calculator.preferences = calculator.preferences.deep_dup if new_calculator.respond_to?(:preferences=) && calculator.respond_to?(:preferences)
            new_calculator
          end
        end
      end
    end
  end
end
