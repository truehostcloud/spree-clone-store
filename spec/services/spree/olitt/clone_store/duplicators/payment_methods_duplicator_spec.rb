require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe PaymentMethodsDuplicator do
          describe '#duplicate' do
            it 'clones payment methods from the source store without copying credentials' do
              old_store = instance_double('Spree::Store')
              new_store = instance_double('Spree::Store', id: 44)
              vendor = instance_double('Spree::Vendor', id: 12)
              source_payment_method = instance_double(
                'Spree::PaymentMethod',
                id: 7,
                type: 'Spree::Gateway::PayPalGateway',
                name: 'PayPal',
                description: 'Primary checkout gateway',
                active: true,
                display_on: 'both',
                auto_capture: true,
                position: 1,
                preferences: { 'login' => 'merchant@example.com' },
                settings: { 'mode' => 'live' },
                public_metadata: { 'provider' => 'paypal' },
                private_metadata: { 'secret_present' => true }
              )
              cloned_payment_method = instance_double('Spree::PaymentMethod')

              duplicator = described_class.new(old_store: old_store, new_store: new_store, vendor: vendor)

              allow(duplicator).to receive(:source_payment_methods).and_return([source_payment_method])
              allow(duplicator).to receive(:existing_payment_method).with(payment_method: source_payment_method).and_return(nil)
              allow(source_payment_method).to receive(:dup).and_return(cloned_payment_method)
              allow(duplicator).to receive(:assign_vendor).with(model_instance: cloned_payment_method, vendor: vendor)

              allow(cloned_payment_method).to receive(:name=)
              allow(cloned_payment_method).to receive(:description=)
              allow(cloned_payment_method).to receive(:active=)
              allow(cloned_payment_method).to receive(:display_on=)
              allow(cloned_payment_method).to receive(:auto_capture=)
              allow(cloned_payment_method).to receive(:position=)
              allow(cloned_payment_method).to receive(:public_metadata=)
              allow(cloned_payment_method).to receive(:stores=)
              allow(cloned_payment_method).to receive(:created_at=)
              allow(cloned_payment_method).to receive(:updated_at=)
              allow(cloned_payment_method).to receive(:deleted_at=)
              allow(duplicator).to receive(:save_model).with(model_instance: cloned_payment_method, context: 'payment method 7').and_return(true)

              duplicator.duplicate

              expect(source_payment_method).to have_received(:dup)
              expect(cloned_payment_method).to have_received(:name=).with('PayPal')
              expect(cloned_payment_method).not_to have_received(:preferences=)
              expect(cloned_payment_method).not_to have_received(:settings=)
              expect(cloned_payment_method).not_to have_received(:private_metadata=)
              expect(cloned_payment_method).to have_received(:stores=).with([new_store])
            end
          end
        end
      end
    end
  end
end