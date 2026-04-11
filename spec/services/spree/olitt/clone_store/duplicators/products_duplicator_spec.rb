require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe ProductsDuplicator do
          describe '#handle_clone_products' do
            it 'continues cloning later products when an earlier product fails' do
              first_product = instance_double('Spree::Product', id: 1, slug: 'first-product')
              second_product = instance_double('Spree::Product', id: 2, slug: 'second-product')
              products_relation = instance_double('ActiveRecord::Relation')
              old_store = instance_double('Spree::Store', products: products_relation)
              new_store = instance_double('Spree::Store', code: 'new-store')
              vendor = instance_double('Spree::Vendor', id: 99)
              cloned_product = instance_double('Spree::Product')

              allow(products_relation).to receive(:includes).and_return(products_relation)
              allow(products_relation).to receive(:limit).and_return([first_product, second_product])

              duplicator = described_class.new(
                old_store: old_store,
                new_store: new_store,
                vendor: vendor,
                taxon_cache: {}
              )

              allow(duplicator).to receive(:save_product).with(old_product: first_product).and_raise(StandardError, 'first product failed')
              allow(duplicator).to receive(:save_product).with(old_product: second_product) do
                duplicator.products_cache[second_product.slug] = [cloned_product]
              end

              duplicator.handle_clone_products

              expect(duplicator.products_cache[second_product.slug]).to eq([cloned_product])
              expect(duplicator.errors).to include('product 1: first product failed')
            end
          end
        end
      end
    end
  end
end
