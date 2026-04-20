require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe VendorAddressesDuplicator do
          describe '#handle_clone_vendor_addresses' do
            it 'copies billing and returns addresses from the source vendor' do
              billing_address = instance_double('Spree::BillingAddress', attributes: {
                'firstname' => 'Jane',
                'lastname' => 'Doe',
                'company' => 'ACME',
                'address1' => '123 Market Street',
                'address2' => 'Suite 2',
                'city' => 'Nairobi',
                'zipcode' => '00100',
                'phone' => '+254700000000',
                'state_name' => 'Nairobi County',
                'alternative_phone' => nil,
                'state_id' => nil,
                'country_id' => 1,
                'public_metadata' => {},
                'private_metadata' => {}
              })
              returns_address = instance_double('Spree::ReturnsAddress', attributes: {
                'firstname' => 'Warehouse',
                'lastname' => 'Team',
                'company' => 'ACME',
                'address1' => 'Returns Street',
                'address2' => nil,
                'city' => 'Nairobi',
                'zipcode' => '00200',
                'phone' => '+254711111111',
                'state_name' => 'Nairobi County',
                'alternative_phone' => nil,
                'state_id' => nil,
                'country_id' => 1,
                'public_metadata' => {},
                'private_metadata' => {}
              })

              source_vendor = instance_double(
                'Spree::Vendor',
                billing_address: billing_address,
                returns_address: returns_address
              )
              old_store = instance_double('Spree::Store', vendor: source_vendor)
              vendor = instance_double('Spree::Vendor', billing_address: nil, returns_address: nil)
              new_billing_address = instance_double('Spree::BillingAddress')
              new_returns_address = instance_double('Spree::ReturnsAddress')

              allow(Spree::BillingAddress).to receive(:new).and_return(new_billing_address)
              allow(Spree::ReturnsAddress).to receive(:new).and_return(new_returns_address)

              [new_billing_address, new_returns_address].each do |address|
                allow(address).to receive(:assign_attributes)
                allow(address).to receive(:user=)
                allow(address).to receive(:deleted_at=)
              end

              allow(vendor).to receive(:billing_address=)
              allow(vendor).to receive(:returns_address=)
              allow(vendor).to receive(:save).and_return(true)

              duplicator = described_class.new(
                old_store: old_store,
                new_store: instance_double('Spree::Store'),
                vendor: vendor
              )

              duplicator.handle_clone_vendor_addresses

              expect(new_billing_address).to have_received(:assign_attributes).with(hash_including('firstname' => 'Jane'))
              expect(new_returns_address).to have_received(:assign_attributes).with(hash_including('address1' => 'Returns Street'))
              expect(vendor).to have_received(:billing_address=).with(new_billing_address)
              expect(vendor).to have_received(:returns_address=).with(new_returns_address)
            end
          end
        end
      end
    end
  end
end