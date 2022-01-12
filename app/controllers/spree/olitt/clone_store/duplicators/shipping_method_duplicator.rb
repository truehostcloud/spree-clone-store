module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class ShippingMethodDuplicator < BaseDuplicator
          def initialize(vendor)
            @vendor = vendor
          end

          def duplicate
            # Get clone shipping methods from environment
            if ENV['CLONE_SHIPPING_METHODS_IDS'].is_present?
              shipping_methods_ids = ENV['CLONE_SHIPPING_METHODS_IDS'].split(',')
              shipping_methods_ids.each do |shipping_method_id|
                shipping_method = Spree::ShippingMethod.find(shipping_method_id)
                new_shipping_method = shipping_method.dup
                new_shipping_method.vendor_id = @vendor
                new_shipping_method.save
              end
            end
          end
        end
      end
    end
  end
end
