require 'spec_helper'

module Spree
  module Olitt
    module CloneStore
      describe StoreCloneRunner do
        describe '#call category cloning gate' do
          let(:old_store) { instance_double('Spree::Store') }
          let(:new_store) { instance_double('Spree::Store') }
          let(:vendor) { instance_double('Spree::Vendor') }
          let(:taxonomies_duplicator) { instance_double(Duplicators::TaxonomiesDuplicator).as_null_object }
          let(:taxons_duplicator) { instance_double(Duplicators::TaxonsDuplicator).as_null_object }

          before do
            allow(Duplicators::LinkedResourceDuplicator).to receive(:new).and_return(instance_double(Duplicators::LinkedResourceDuplicator).as_null_object)
            allow(Duplicators::StockLocationsDuplicator).to receive(:new).and_return(instance_double(Duplicators::StockLocationsDuplicator).as_null_object)
            allow(Duplicators::VendorAddressesDuplicator).to receive(:new).and_return(instance_double(Duplicators::VendorAddressesDuplicator).as_null_object)
            allow(Duplicators::TaxonomiesDuplicator).to receive(:new).and_return(taxonomies_duplicator)
            allow(Duplicators::TaxonsDuplicator).to receive(:new).and_return(taxons_duplicator)
            allow(Duplicators::PagesDuplicator).to receive(:new).and_return(instance_double(Duplicators::PagesDuplicator).as_null_object)
            allow(Duplicators::ShippingCategoriesDuplicator).to receive(:new).and_return(instance_double(Duplicators::ShippingCategoriesDuplicator).as_null_object)
            allow(Duplicators::OptionTypesDuplicator).to receive(:new).and_return(instance_double(Duplicators::OptionTypesDuplicator).as_null_object)
            allow(Duplicators::ProductsDuplicator).to receive(:new).and_return(instance_double(Duplicators::ProductsDuplicator).as_null_object)
            allow(Duplicators::StockItemsDuplicator).to receive(:new).and_return(instance_double(Duplicators::StockItemsDuplicator).as_null_object)
            allow(Duplicators::SectionsDuplicator).to receive(:new).and_return(instance_double(Duplicators::SectionsDuplicator).as_null_object)
            allow(Duplicators::MenusDuplicator).to receive(:new).and_return(instance_double(Duplicators::MenusDuplicator).as_null_object)
            allow(Duplicators::MenuItemsDuplicator).to receive(:new).and_return(instance_double(Duplicators::MenuItemsDuplicator).as_null_object)
            allow(Duplicators::PaymentMethodsDuplicator).to receive(:new).and_return(instance_double(Duplicators::PaymentMethodsDuplicator).as_null_object)
            allow(Duplicators::ShippingMethodsDuplicator).to receive(:new).and_return(instance_double(Duplicators::ShippingMethodsDuplicator).as_null_object)
            allow(ZoneResolver).to receive(:new).and_return(instance_double(ZoneResolver))
          end

          def run
            runner = described_class.new(old_store: old_store, new_store: new_store, vendor: vendor)
            allow(runner).to receive(:attach_store_images)
            runner.call
          end

          context 'when CLONE_CATEGORIES_ENABLED is unset (default)' do
            before { allow(ENV).to receive(:fetch).and_call_original }

            it 'clones taxonomies and taxons' do
              run

              expect(taxonomies_duplicator).to have_received(:handle_clone_taxonomies)
              expect(taxons_duplicator).to have_received(:handle_clone_taxons)
            end
          end

          context "when CLONE_CATEGORIES_ENABLED is 'false'" do
            before do
              allow(ENV).to receive(:fetch).and_call_original
              allow(ENV).to receive(:fetch).with('CLONE_CATEGORIES_ENABLED', 'true').and_return('false')
            end

            it 'skips taxonomy and taxon cloning' do
              run

              expect(taxonomies_duplicator).not_to have_received(:handle_clone_taxonomies)
              expect(taxons_duplicator).not_to have_received(:handle_clone_taxons)
            end
          end
        end
      end
    end
  end
end
