module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class TaxonsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers
          attr_reader :errors

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store

            @old_taxons_by_parent = @old_store.taxons.includes(:taxonomy, :parent).group_by(&:parent_id)
            @new_taxonomies_by_name = @new_store.taxonomies.group_by(&:name)

            @new_taxons_cache = @new_store.taxons.group_by(&:permalink)
            @errors = []
          end

          def handle_clone_taxons
            clone_child_taxons(parent_taxon_id: nil)
          end

          def clone_child_taxons(parent_taxon_id:)
            return if are_errors_present?

            return unless @old_taxons_by_parent.key?(parent_taxon_id)

            old_child_taxons = get_old_child_taxons(parent_taxon_id: parent_taxon_id)

            return old_child_taxons.each { |child_taxon| clone_child_taxons(parent_taxon_id: child_taxon.id) } if parent_taxon_id.nil?

            new_child_taxons = reassign_taxon_properies(old_child_taxons: old_child_taxons)

            save_new_taxons(new_child_taxons: new_child_taxons)

            return if are_errors_present?

            old_child_taxons.each { |child_taxon| clone_child_taxons(parent_taxon_id: child_taxon.id) }
          end

          def reassign_taxon_properies(old_child_taxons:)
            old_child_taxons.map(&:dup).map do |old_taxon|
              old_taxon.taxonomy = get_new_taxonomy(old_taxon: old_taxon)
              old_taxon.parent = get_new_parent_taxon(old_taxon: old_taxon)
              attributes = old_taxon.attributes
              attributes = attributes.except('lft', 'rgt', 'depth')
              Spree::Taxon.new attributes
            end
          end

          def save_new_taxons(new_child_taxons:)
            new_child_taxons.each do |taxon|
              unless taxon.save
                @errors << taxon.errors
                break
              end
              @new_taxons_cache[taxon.permalink] = [taxon]
            end
          end

          def are_errors_present?
            !@errors.empty?
          end

          def get_old_child_taxons(parent_taxon_id:)
            @old_taxons_by_parent[parent_taxon_id]
          end

          def get_new_taxonomy(old_taxon:)
            @new_taxonomies_by_name[old_taxon.taxonomy.name].first
          end

          def get_new_parent_taxon(old_taxon:)
            @new_taxons_cache[old_taxon.parent.permalink].first
          end
        end
      end
    end
  end
end
