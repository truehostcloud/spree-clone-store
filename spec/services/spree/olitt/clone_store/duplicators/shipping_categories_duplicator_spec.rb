require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe ShippingCategoriesDuplicator do
          describe '#handle_clone_shipping_categories' do
            it 'duplicates unique source shipping categories and caches them' do
              shipping_category = instance_double('Spree::ShippingCategory', id: 3, name: 'Physical Goods')
              product = instance_double('Spree::Product', shipping_category: shipping_category)
              products_relation = instance_double('ActiveRecord::Relation')
              source_vendor = instance_double('Spree::Vendor', shipping_methods: [])
              old_store = double('Spree::Store', products: products_relation, vendor: source_vendor)
              vendor = instance_double('Spree::Vendor', id: 19)
              new_shipping_category = instance_double('Spree::ShippingCategory')
              vendor_shipping_categories = instance_double('ActiveRecord::Relation')
              vendor_shipping_categories_without_current = instance_double('ActiveRecord::Relation')
              shipping_categories_named_scope = instance_double('ActiveRecord::Relation')

              allow(products_relation).to receive(:includes).with(:shipping_category).and_return([product])
              allow(Spree::ShippingCategory).to receive(:where).with(vendor_id: 19).and_return(vendor_shipping_categories)
              allow(vendor_shipping_categories).to receive(:find_by).with(name: 'Physical Goods').and_return(nil)
              allow(vendor_shipping_categories).to receive(:where).and_return(vendor_shipping_categories_without_current)
              allow(vendor_shipping_categories_without_current).to receive(:not).and_return(vendor_shipping_categories_without_current)
              allow(vendor_shipping_categories_without_current).to receive(:where).with(name: 'Physical Goods').and_return(shipping_categories_named_scope)
              allow(shipping_categories_named_scope).to receive(:exists?).and_return(false)

              allow(Spree::ShippingCategory).to receive(:new).and_return(new_shipping_category)
              allow(new_shipping_category).to receive(:vendor_id=)
              allow(new_shipping_category).to receive(:name=)
              allow(new_shipping_category).to receive(:id).and_return(nil)
              allow(new_shipping_category).to receive(:save).and_return(true)

              duplicator = described_class.new(old_store: old_store, new_store: instance_double('Spree::Store'), vendor: vendor)
              allow(duplicator).to receive(:unique_shipping_category_name).and_return('Physical Goods')

              duplicator.handle_clone_shipping_categories

              expect(new_shipping_category).to have_received(:vendor_id=).with(19)
              expect(new_shipping_category).to have_received(:name=).with('Physical Goods')
              expect(duplicator.shipping_categories_cache[3]).to eq([new_shipping_category])
              expect(duplicator.shipping_categories_cache['Physical Goods']).to eq([new_shipping_category])
            end
          end
        end
      end
    end
  end
end