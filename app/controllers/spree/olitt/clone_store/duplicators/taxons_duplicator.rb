module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class TaxonsDuplicator < BaseDuplicator
          attr_reader :taxons_cache

          def initialize(old_store:, new_store:, taxonomies_cache:, root_taxons:)
            super()
            @old_store = old_store
            @new_store = new_store

            @taxons_cache = root_taxons
            @new_taxonomies_by_name = taxonomies_cache

            @depth = 1

            @old_taxons_by_depth = @old_store.taxons.includes(%i[taxonomy parent]).group_by(&:depth)
          end

          def handle_clone_taxons
            while @old_taxons_by_depth[@depth] && !errors_are_present?
              old_taxons = @old_taxons_by_depth[@depth]
              old_taxons.each do |old_taxon|
                save_new_taxon(old_taxon: old_taxon)
                break if errors_are_present?
              end
              @depth += 1
            end
          end

          def save_new_taxon(old_taxon:)
            new_taxon = old_taxon.dup
            new_taxon.taxonomy = get_new_taxonomy(old_taxon: old_taxon)
            new_taxon.parent = get_new_parent_taxon(old_taxon: old_taxon)
            attributes = new_taxon.attributes
            attributes = attributes.except('lft', 'rgt', 'depth')
            new_taxon = Spree::Taxon.new attributes
            save_model(model: new_taxon)
            return if errors_are_present?

            @taxons_cache[new_taxon.permalink] = [new_taxon]
          end

          def get_old_child_taxons(parent_taxon_id:)
            @old_taxons_by_parent[parent_taxon_id]
          end

          def get_new_taxonomy(old_taxon:)
            @new_taxonomies_by_name[old_taxon.taxonomy.name].first
          end

          def get_new_parent_taxon(old_taxon:)
            @taxons_cache[old_taxon.parent.permalink].first
          end
        end
      end
    end
  end
end
