module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ShippingMethodsDuplicator < BaseDuplicator
          def initialize(vendor:, new_store:)
            super()
            @vendor = vendor
            @new_store = new_store
          end

          def duplicate
            # Get clone shipping methods from environment
            vendor_shipping_methods = @vendor.shipping_methods.all
            if ENV['CLONE_SHIPPING_METHODS_IDS'].present? && (vendor_shipping_methods.count == 0)
              shipping_methods_ids = ENV['CLONE_SHIPPING_METHODS_IDS'].split(',')
              shipping_methods_ids.each do |shipping_method_id|
                shipping_method = Spree::ShippingMethod.find(shipping_method_id)
                if shipping_method.present?
                  new_shipping_method = shipping_method.dup
                  new_shipping_method.vendor = @vendor
                  new_shipping_method.shipping_categories = shipping_method.shipping_categories.all
                  new_shipping_method.calculator = duplicate_calculator(shipping_method.calculator)
                  new_shipping_method.name = "#{shipping_method.name} - #{@new_store.name}"
                  new_shipping_method.zones = shipping_method.zones.all
                  new_shipping_method.created_at = Time.zone.now
                  new_shipping_method.updated_at = nil
                  save_model(model_instance: new_shipping_method)
                end
              end
            end
          end
          def duplicate_calculator(calculator)
            if calculator.present?
              new_calculator = calculator.dup
              new_calculator.created_at = Time.zone.now
              new_calculator.updated_at = nil
              new_calculator.save
              new_calculator
            end
          end
        end
      end
    end
  end
end
