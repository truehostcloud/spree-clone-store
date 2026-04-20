module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class PaymentMethodsDuplicator < BaseDuplicator
          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
          end

          def duplicate
            source_payment_methods.each do |payment_method|
              next if payment_method.blank?

              new_payment_method = existing_payment_method(payment_method: payment_method) || payment_method.dup
              assign_vendor(model_instance: new_payment_method, vendor: @vendor)
              assign_payment_method_attributes(new_payment_method: new_payment_method, payment_method: payment_method)
              new_payment_method.stores = [@new_store]
              new_payment_method.created_at = nil if new_payment_method.respond_to?(:created_at=)
              new_payment_method.updated_at = nil if new_payment_method.respond_to?(:updated_at=)
              new_payment_method.deleted_at = nil if new_payment_method.respond_to?(:deleted_at=)
              save_model(model_instance: new_payment_method, context: "payment method #{payment_method.id}")
            rescue StandardError => e
              record_errors([e.message], context: "payment method #{payment_method.id}")
            end
          end

          private

          def source_payment_methods
            source_methods = source_store_payment_methods
            return source_methods if source_methods.present?

            fallback_payment_methods
          end

          def source_store_payment_methods
            return [] unless @old_store.respond_to?(:payment_methods)

            payment_methods = @old_store.payment_methods.includes(:stores).to_a
            return payment_methods if source_vendor.blank?

            payment_methods.select do |payment_method|
              payment_method.respond_to?(:vendor_id) && [source_vendor.id, nil].include?(payment_method.vendor_id)
            end
          end

          def source_vendor
            return @source_vendor if defined?(@source_vendor)

            @source_vendor = @old_store.respond_to?(:vendor) ? @old_store.vendor : nil
          end

          def fallback_payment_methods
            payment_methods_ids = ENV['CLONE_PAYMENT_METHODS_IDS'].to_s.split(',').map(&:strip).reject(&:blank?)
            return [] if payment_methods_ids.empty?

            Spree::PaymentMethod.where(id: payment_methods_ids).includes(:stores).to_a
          end

          def existing_payment_method(payment_method:)
            Spree::PaymentMethod.joins(:stores).find_by(
              vendor_id: @vendor.id,
              type: payment_method.type,
              name: payment_method.name,
              spree_stores: { id: @new_store.id }
            )
          end

          def assign_payment_method_attributes(new_payment_method:, payment_method:)
            new_payment_method.name = payment_method.name
            new_payment_method.description = payment_method.description if new_payment_method.respond_to?(:description=)
            new_payment_method.active = payment_method.active if new_payment_method.respond_to?(:active=)
            new_payment_method.display_on = payment_method.display_on if new_payment_method.respond_to?(:display_on=)
            new_payment_method.auto_capture = payment_method.auto_capture if new_payment_method.respond_to?(:auto_capture=)
            new_payment_method.position = payment_method.position if new_payment_method.respond_to?(:position=) && payment_method.respond_to?(:position)
            new_payment_method.public_metadata = payment_method.public_metadata.deep_dup if new_payment_method.respond_to?(:public_metadata=) && payment_method.respond_to?(:public_metadata)
          end
        end
      end
    end
  end
end
