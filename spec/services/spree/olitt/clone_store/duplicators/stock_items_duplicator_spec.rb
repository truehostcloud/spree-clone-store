require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe StockItemsDuplicator do
          describe '#handle_clone_stock_items' do
            it 'copies stock counts to the cloned variant and stock location' do
              old_stock_item = instance_double(
                'Spree::StockItem',
                id: 21,
                stock_location_id: 7,
                count_on_hand: 15,
                backorderable: true,
                public_metadata: {},
                private_metadata: {},
                external_id: 'ext-1'
              )
              old_variant = instance_double('Spree::Variant', id: 4, stock_items: [old_stock_item])
              product = instance_double('Spree::Product', variants_including_master: [old_variant])
              products_relation = instance_double('ActiveRecord::Relation')
              old_store = instance_double('Spree::Store', products: products_relation)
              new_stock_location = instance_double('Spree::StockLocation')
              new_stock_item = instance_double('Spree::StockItem')
              new_stock_items_relation = instance_double('ActiveRecord::Relation')
              new_variant = instance_double('Spree::Variant', stock_items: new_stock_items_relation)

              allow(products_relation).to receive(:includes).with(variants_including_master: :stock_items).and_return([product])
              allow(new_stock_items_relation).to receive(:find_or_initialize_by).with(stock_location: new_stock_location).and_return(new_stock_item)
              allow(new_stock_item).to receive(:count_on_hand=)
              allow(new_stock_item).to receive(:backorderable=)
              allow(new_stock_item).to receive(:public_metadata=)
              allow(new_stock_item).to receive(:private_metadata=)
              allow(new_stock_item).to receive(:external_id=)
              allow(new_stock_item).to receive(:deleted_at=)
              allow(new_stock_item).to receive(:save).and_return(true)

              duplicator = described_class.new(
                old_store: old_store,
                new_store: instance_double('Spree::Store'),
                vendor: instance_double('Spree::Vendor', stock_locations: instance_double('ActiveRecord::Relation')),
                stock_locations_cache: { 7 => [new_stock_location] },
                variants_cache: { 4 => [new_variant] }
              )

              duplicator.handle_clone_stock_items

              expect(new_stock_item).to have_received(:count_on_hand=).with(15)
              expect(new_stock_item).to have_received(:backorderable=).with(true)
              expect(new_stock_item).to have_received(:external_id=).with('ext-1')
            end

            it 'creates a default stock item when the source variant has none' do
              old_variant = instance_double('Spree::Variant', id: 4, stock_items: [])
              product = instance_double('Spree::Product', variants_including_master: [old_variant])
              products_relation = instance_double('ActiveRecord::Relation')
              old_store = instance_double('Spree::Store', products: products_relation)
              default_stock_location = instance_double('Spree::StockLocation')
              new_stock_item = instance_double('Spree::StockItem')
              new_stock_items_relation = instance_double('ActiveRecord::Relation')
              vendor_stock_locations = instance_double('ActiveRecord::Relation')
              new_variant = instance_double('Spree::Variant', stock_items: new_stock_items_relation)

              allow(products_relation).to receive(:includes).with(variants_including_master: :stock_items).and_return([product])
              allow(new_stock_items_relation).to receive(:find_or_initialize_by).with(stock_location: default_stock_location).and_return(new_stock_item)
              allow(new_stock_items_relation).to receive(:exists?).and_return(false)
              allow(new_stock_item).to receive(:count_on_hand=)
              allow(new_stock_item).to receive(:backorderable=)
              allow(new_stock_item).to receive(:deleted_at=)
              allow(new_stock_item).to receive(:save).and_return(true)
              allow(vendor_stock_locations).to receive(:order).with(default: :desc, id: :asc).and_return([default_stock_location])

              duplicator = described_class.new(
                old_store: old_store,
                new_store: instance_double('Spree::Store'),
                vendor: instance_double('Spree::Vendor', stock_locations: vendor_stock_locations),
                stock_locations_cache: { default: [default_stock_location] },
                variants_cache: { 4 => [new_variant] }
              )

              duplicator.handle_clone_stock_items

              expect(new_stock_item).to have_received(:count_on_hand=).with(5)
              expect(new_stock_item).to have_received(:backorderable=).with(false)
            end
          end
        end
      end
    end
  end
end