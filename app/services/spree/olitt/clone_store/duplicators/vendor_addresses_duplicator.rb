module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class VendorAddressesDuplicator < BaseDuplicator
          ADDRESS_ATTRIBUTES = %w[
            firstname lastname company address1 address2 city zipcode phone state_name
            alternative_phone state_id country_id public_metadata private_metadata
          ].freeze

          def initialize(old_store:, new_store:, vendor:, stock_locations_duplicator: nil)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @stock_locations_duplicator = stock_locations_duplicator
          end

          def handle_clone_vendor_addresses
            source_vendor = source_vendor_record
            clone_billing_address(source_vendor: source_vendor)
            clone_returns_address(source_vendor: source_vendor)
          end

          private

          def source_vendor_record
            return @source_vendor_record if defined?(@source_vendor_record)

            @source_vendor_record = @old_store.respond_to?(:vendor) ? @old_store.vendor : nil
          end

          def clone_billing_address(source_vendor:)
            source_address = source_vendor&.billing_address || fallback_address_from_stock_location
            clone_address(
              source_address: source_address,
              target_address: @vendor.billing_address,
              target_class: Spree::BillingAddress,
              writer: :billing_address=
            )
          end

          def clone_returns_address(source_vendor:)
            source_address = source_vendor&.returns_address || source_vendor&.billing_address || fallback_address_from_stock_location
            clone_address(
              source_address: source_address,
              target_address: @vendor.returns_address,
              target_class: Spree::ReturnsAddress,
              writer: :returns_address=
            )
          end

          def clone_address(source_address:, target_address:, target_class:, writer:)
            return if source_address.blank?

            address = target_address || target_class.new
            assign_address_attributes(address: address, source_address: source_address)
            @vendor.public_send(writer, address)

            save_model(model_instance: @vendor, context: target_class.name.demodulize.underscore.humanize.downcase)
          rescue StandardError => e
            record_errors([e.message], context: target_class.name.demodulize.underscore.humanize.downcase)
          end

          def assign_address_attributes(address:, source_address:)
            address.assign_attributes(source_address.attributes.slice(*ADDRESS_ATTRIBUTES))
            address.user = nil if address.respond_to?(:user=)
            address.deleted_at = nil if address.respond_to?(:deleted_at=)
          end

          def fallback_address_from_stock_location
            stock_location = Array(@stock_locations_duplicator&.cloned_locations).find(&:default) ||
                             Array(@stock_locations_duplicator&.cloned_locations).first ||
                             @vendor.stock_locations.order(default: :desc, id: :asc).first
            return if stock_location.blank?

            stock_location.address
          end
        end
      end
    end
  end
end