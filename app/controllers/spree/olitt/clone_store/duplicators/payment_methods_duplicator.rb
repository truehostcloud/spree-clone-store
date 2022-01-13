module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class PaymentMethodsDuplicator < BaseDuplicator
          def initialize(new_store:)
            super()
            @new_store = new_store
          end

          def duplicate
            # Get clone payment method from environment
            if ENV['CLONE_PAYMENT_METHODS_IDS'].present?
              payment_methods_ids = ENV['CLONE_PAYMENT_METHODS_IDS'].split(',')
              payment_methods_ids.each do |payment_method_id|
                payment_method = Spree::PaymentMethod.find(payment_method_id)
                if payment_method.present?
                  new_payment_method = payment_method.dup
                  new_payment_method.stores = [@new_store]
                  new_payment_method.created_at = Time.now
                  new_payment_method.updated_at = nil
                  new_payment_method.save
                end
              end
            end
          end
        end
      end
    end
  end
end
