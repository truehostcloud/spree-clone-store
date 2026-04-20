require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe ProductsDuplicator do
          describe '#resolve_tax_category' do
            it 'reuses a matching shared tax category when the original id is unavailable' do
              old_store = instance_double('Spree::Store', products: instance_double('ActiveRecord::Relation'))
              new_store = instance_double('Spree::Store', code: 'new-store')
              vendor = instance_double('Spree::Vendor', id: 99)
              old_tax_category = instance_double('Spree::TaxCategory', id: 21, name: 'Clothing', tax_code: 'CLTH', is_default?: false)
              new_tax_category = instance_double('Spree::TaxCategory')

              duplicator = described_class.new(
                old_store: old_store,
                new_store: new_store,
                vendor: vendor,
                taxon_cache: {}
              )

              allow(Spree::TaxCategory).to receive(:find_by).with(id: 21).and_return(nil)
              allow(Spree::TaxCategory).to receive(:find_by).with(name: 'Clothing').and_return(new_tax_category)

              resolved_tax_category = duplicator.send(:resolve_tax_category, old_tax_category)

              expect(resolved_tax_category).to eq(new_tax_category)
            end
          end
        end
      end
    end
  end
end