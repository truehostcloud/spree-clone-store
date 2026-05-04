require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe StockLocationsDuplicator do
          describe '#handle_clone_stock_locations' do
            it 'duplicates vendor stock locations from the source vendor' do
              old_location = instance_double(
                'Spree::StockLocation',
                id: 7,
                name: 'Main Warehouse',
                admin_name: 'HQ',
                address1: '123 Market Street',
                address2: 'Suite 2',
                city: 'Nairobi',
                state: nil,
                state_name: 'Nairobi County',
                country: :country,
                zipcode: '00100',
                phone: '+254700000000',
                active: true,
                backorderable_default: false,
                propagate_all_variants: true,
                company: 'ACME',
                default: true
              )

              stock_locations_relation = instance_double('ActiveRecord::Relation')
              source_vendor = instance_double('Spree::Vendor', stock_locations: stock_locations_relation)
              old_store = double('Spree::Store', vendor: source_vendor)
              new_store = instance_double('Spree::Store', name: 'New Store', default_country: :country)
              vendor_stock_locations = instance_double('ActiveRecord::Relation')
              vendor = instance_double('Spree::Vendor', id: 9, name: 'vendor@example.com', stock_locations: vendor_stock_locations)
              new_location = instance_double('Spree::StockLocation')
              vendor_stock_locations_without_current = instance_double('ActiveRecord::Relation')
              stock_locations_named_scope = instance_double('ActiveRecord::Relation')

              allow(stock_locations_relation).to receive(:includes).with(:country, :state).and_return(stock_locations_relation)
              allow(stock_locations_relation).to receive(:order).with(default: :desc, id: :asc).and_return([old_location])
              allow(vendor_stock_locations).to receive(:order).with(default: :desc, id: :asc).and_return([])
              allow(vendor_stock_locations).to receive(:find_by).with(name: 'Main Warehouse').and_return(nil)
              allow(vendor_stock_locations).to receive(:where).and_return(vendor_stock_locations_without_current)
              allow(vendor_stock_locations_without_current).to receive(:not).and_return(vendor_stock_locations_without_current)
              allow(vendor_stock_locations_without_current).to receive(:where).with(name: 'Main Warehouse').and_return(stock_locations_named_scope)
              allow(stock_locations_named_scope).to receive(:exists?).and_return(false)

              allow(Spree::StockLocation).to receive(:new).and_return(new_location)
              allow(new_location).to receive(:name=)
              allow(new_location).to receive(:admin_name=)
              allow(new_location).to receive(:address1=)
              allow(new_location).to receive(:address2=)
              allow(new_location).to receive(:city=)
              allow(new_location).to receive(:state=)
              allow(new_location).to receive(:state_name=)
              allow(new_location).to receive(:country=)
              allow(new_location).to receive(:zipcode=)
              allow(new_location).to receive(:phone=)
              allow(new_location).to receive(:active=)
              allow(new_location).to receive(:backorderable_default=)
              allow(new_location).to receive(:propagate_all_variants=)
              allow(new_location).to receive(:company=)
              allow(new_location).to receive(:default=)
              allow(new_location).to receive(:deleted_at=)
              allow(new_location).to receive(:vendor_id=)
              allow(new_location).to receive(:id).and_return(nil)
              allow(new_location).to receive(:save).and_return(true)

              duplicator = described_class.new(old_store: old_store, new_store: new_store, vendor: vendor)

              duplicator.handle_clone_stock_locations

              expect(new_location).to have_received(:vendor_id=).with(9)
              expect(new_location).to have_received(:name=).with('Main Warehouse')
              expect(new_location).to have_received(:country=).with(:country)
              expect(duplicator.cloned_locations).to include(new_location)
            end

            it 'creates a fallback default stock location when the source store has none' do
              products_relation = instance_double('ActiveRecord::Relation')
              old_store = double('Spree::Store', vendor: nil, products: products_relation)
              new_store = instance_double('Spree::Store', name: 'Gallery shop', default_country: :us_country)
              vendor_stock_locations = instance_double('ActiveRecord::Relation')
              vendor = instance_double('Spree::Vendor', id: 9, name: 'vendor@example.com', stock_locations: vendor_stock_locations)
              new_location = instance_double('Spree::StockLocation')
              vendor_stock_locations_without_current = instance_double('ActiveRecord::Relation')
              stock_locations_named_scope = instance_double('ActiveRecord::Relation')

              allow(products_relation).to receive(:includes).with(variants_including_master: { stock_items: :stock_location }).and_return([])
              allow(vendor_stock_locations).to receive(:order).with(default: :desc, id: :asc).and_return([])
              allow(vendor_stock_locations).to receive(:find_by).with(default: true).and_return(nil)
              allow(vendor_stock_locations).to receive(:where).and_return(vendor_stock_locations_without_current)
              allow(vendor_stock_locations_without_current).to receive(:not).and_return(vendor_stock_locations_without_current)
              allow(vendor_stock_locations_without_current).to receive(:where).with(name: 'US location').and_return(stock_locations_named_scope)
              allow(stock_locations_named_scope).to receive(:exists?).and_return(false)

              allow(Spree::StockLocation).to receive(:new).and_return(new_location)
              allow(new_location).to receive(:name=)
              allow(new_location).to receive(:admin_name=)
              allow(new_location).to receive(:country=)
              allow(new_location).to receive(:active=)
              allow(new_location).to receive(:backorderable_default=)
              allow(new_location).to receive(:propagate_all_variants=)
              allow(new_location).to receive(:company=)
              allow(new_location).to receive(:default=)
              allow(new_location).to receive(:deleted_at=)
              allow(new_location).to receive(:vendor_id=)
              allow(new_location).to receive(:id).and_return(nil)
              allow(new_location).to receive(:save).and_return(true)

              duplicator = described_class.new(old_store: old_store, new_store: new_store, vendor: vendor)

              duplicator.handle_clone_stock_locations

              expect(new_location).to have_received(:name=).with('US location')
              expect(new_location).to have_received(:country=).with(:us_country)
              expect(new_location).to have_received(:default=).with(true)
              expect(duplicator.locations_cache[:default]).to eq([new_location])
            end
          end
        end
      end
    end
  end
end