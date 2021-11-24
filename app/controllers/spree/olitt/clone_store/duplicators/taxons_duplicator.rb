module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class TaxonsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = Spree::Store.includes(:taxonomies).find_by(id: new_store.id)
          end

          def handle_clone_taxons
            old_root_taxons = @old_store.taxons.where(parent: nil).order(depth: :asc).order(id: :asc)
            old_root_taxons.each { |root_taxon| return false unless clone_taxon(root_taxon, terminate: false) }
            true
          end

          def clone_taxon(parent_taxon, terminate: false)
            return false if terminate

            old_taxons = @old_store.taxons.where(parent: parent_taxon, taxonomy: parent_taxon.taxonomy)
                                   .order(depth: :asc).order(id: :asc)
            return false if old_taxons.nil?

            new_taxonomy = @new_store.taxonomies.find_by(name: parent_taxon.taxonomy.name)
            new_parent_taxon = get_new_parent_taxon(new_taxonomy, parent_taxon)

            cloned_taxons = clone_update_taxon(old_taxons, new_taxonomy, new_parent_taxon)
            terminate = true unless save_models(cloned_taxons)

            old_taxons.each { |taxon| return false unless clone_taxon(taxon, terminate: terminate) }
            true
          end

          def clone_update_taxon(old_taxons, new_taxonomy, new_parent_taxon)
            taxons = old_taxons.map do |taxon|
              new_taxon = taxon.dup
              new_taxon.parent = new_parent_taxon
              new_taxon
            end
            attributes_for_each_taxon = get_model_hash(taxons).map do |attributes|
              attributes.except('lft', 'rgt', 'depth')
            end
            new_taxonomy.taxons.build(attributes_for_each_taxon)
          end

          def get_new_parent_taxon(new_taxonomy, old_parent_taxon)
            @new_store.taxons.find_by(permalink: old_parent_taxon.permalink, taxonomy: new_taxonomy)
          end
        end
      end
    end
  end
end
