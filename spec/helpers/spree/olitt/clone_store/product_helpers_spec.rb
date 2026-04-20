require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      describe ProductHelpers do
        subject(:helper_host) do
          Class.new do
            include Spree::Olitt::CloneStore::ProductHelpers
          end.new
        end

        describe '#duplicate_variant' do
          it 'copies variant images and prices alongside option values' do
            option_values = [instance_double('Spree::OptionValue')]
            source_image = instance_double('Spree::Image')
            cloned_image = instance_double('Spree::Image')
            source_price = instance_double('Spree::Price')
            cloned_price = instance_double('Spree::Price')
            variant = instance_double(
              'Spree::Variant',
              sku: 'SKU-1',
              option_values: option_values,
              images: [source_image],
              prices: [source_price]
            )
            new_variant = instance_double('Spree::Variant')

            allow(variant).to receive(:dup).and_return(new_variant)
            allow(helper_host).to receive(:duplicate_image).with(image: source_image).and_return(cloned_image)
            allow(source_price).to receive(:dup).and_return(cloned_price)

            allow(new_variant).to receive(:sku=)
            allow(new_variant).to receive(:deleted_at=)
            allow(new_variant).to receive(:vendor_id=)
            allow(new_variant).to receive(:tax_category=)
            allow(new_variant).to receive(:option_values=)
            allow(new_variant).to receive(:images=)
            allow(new_variant).to receive(:prices=)
            allow(cloned_price).to receive(:deleted_at=)
            allow(cloned_price).to receive(:created_at=)
            allow(cloned_price).to receive(:updated_at=)

            duplicated_variant = helper_host.duplicate_variant(
              variant: variant,
              vendor_id: 12,
              code: 'new-store',
              option_values: option_values,
              tax_category: nil
            )

            expect(duplicated_variant).to eq(new_variant)
            expect(new_variant).to have_received(:images=).with([cloned_image])
            expect(new_variant).to have_received(:prices=).with([cloned_price])
            expect(new_variant).to have_received(:option_values=).with(option_values)
          end
        end
      end
    end
  end
end