require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      module Duplicators
        describe OptionTypesDuplicator do
          describe '#handle_clone_option_types' do
            it 'clones option types and values into vendor-scoped copies' do
              option_value = instance_double(
                'Spree::OptionValue',
                id: 9,
                name: 'large',
                presentation: 'Large',
                position: 1,
                public_metadata: {},
                private_metadata: {}
              )
              option_type = instance_double(
                'Spree::OptionType',
                id: 4,
                vendor_id: 2,
                name: 'size',
                presentation: 'Size',
                position: 1,
                filterable: true,
                public_metadata: {},
                private_metadata: {},
                option_values: [option_value]
              )
              product = instance_double('Spree::Product', option_types: [option_type])
              products_relation = instance_double('ActiveRecord::Relation')
              old_store = instance_double('Spree::Store', products: products_relation)
              new_store = instance_double('Spree::Store', code: 'new-store')
              vendor = instance_double('Spree::Vendor', id: 12)
              new_option_type = instance_double('Spree::OptionType')
              new_option_values_relation = instance_double('ActiveRecord::Relation')
              new_option_value = instance_double('Spree::OptionValue')

              allow(products_relation).to receive(:includes).with(option_types: :option_values).and_return([product])
              allow(Spree::OptionType).to receive(:new).and_return(new_option_type)
              allow(Spree::OptionValue).to receive(:new).and_return(new_option_value)
              allow(new_option_type).to receive(:vendor_id=)
              allow(new_option_type).to receive(:name=)
              allow(new_option_type).to receive(:presentation=)
              allow(new_option_type).to receive(:position=)
              allow(new_option_type).to receive(:filterable=)
              allow(new_option_type).to receive(:public_metadata=)
              allow(new_option_type).to receive(:private_metadata=)
              allow(new_option_type).to receive(:id).and_return(nil)
              allow(new_option_type).to receive(:save).and_return(true)
              allow(new_option_type).to receive(:option_values).and_return(new_option_values_relation)
              allow(new_option_values_relation).to receive(:find_by).with(name: 'large').and_return(nil)

              allow(new_option_value).to receive(:vendor_id=)
              allow(new_option_value).to receive(:option_type=)
              allow(new_option_value).to receive(:name=)
              allow(new_option_value).to receive(:presentation=)
              allow(new_option_value).to receive(:position=)
              allow(new_option_value).to receive(:public_metadata=)
              allow(new_option_value).to receive(:private_metadata=)
              allow(new_option_value).to receive(:save).and_return(true)

              duplicator = described_class.new(old_store: old_store, new_store: new_store, vendor: vendor)
              allow(duplicator).to receive(:unique_option_type_name).and_return('size_new-store')

              duplicator.handle_clone_option_types

              expect(new_option_type).to have_received(:vendor_id=).with(12)
              expect(new_option_type).to have_received(:name=).with('size_new-store')
              expect(new_option_value).to have_received(:option_type=).with(new_option_type)
              expect(duplicator.option_types_cache[4]).to eq([new_option_type])
              expect(duplicator.option_values_cache[9]).to eq([new_option_value])
            end
          end
        end
      end
    end
  end
end