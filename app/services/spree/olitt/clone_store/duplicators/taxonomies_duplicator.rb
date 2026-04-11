module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class TaxonomiesDuplicator < BaseDuplicator
          attr_reader :root_taxons, :taxonomies_cache

          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store
            @root_taxons = {}
            @taxonomies_cache = {}
            @vendor = vendor
          end

          def handle_clone_taxonomies
            taxonomies = @old_store.taxonomies
            taxonomies.each do |old_taxonomy|
              clone_taxonomy(old_taxonomy)
            rescue StandardError => e
              record_errors([e.message], context: "taxonomy #{old_taxonomy.id}")
            end
          end

          def clone_taxonomy(old_taxonomy)
            new_taxonomy = find_or_build_taxonomy(old_taxonomy: old_taxonomy)
            saved = true
            if new_taxonomy.new_record? || new_taxonomy.changed?
              saved = save_model(model_instance: new_taxonomy, context: "taxonomy #{old_taxonomy.id}")
            end
            return unless saved

            @root_taxons[old_taxonomy.root.permalink] = [new_taxonomy.root]
            cache_taxonomies(old_taxonomy: old_taxonomy, new_taxonomy: new_taxonomy)
          end

          def find_or_build_taxonomy(old_taxonomy:)
            new_taxonomy = old_taxonomy.dup
            new_taxonomy.store = @new_store
            assign_vendor(model_instance: new_taxonomy, vendor: @vendor)
            new_taxonomy.name = unique_taxonomy_name(old_taxonomy.name)
            new_taxonomy
          end

          def cache_taxonomies(old_taxonomy:, new_taxonomy:)
            @taxonomies_cache[old_taxonomy.name] = [new_taxonomy]
          end

          def unique_taxonomy_name(base_name)
            unique_value(base_value: base_name, separator: ' ') do |candidate|
              @new_store.taxonomies.with_matching_name(candidate).exists?
            end
          end
        end
      end
    end
  end
end
