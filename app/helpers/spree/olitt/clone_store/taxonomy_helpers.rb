module Spree
  module Olitt
    module CloneStore
      module TaxonomyHelpers
        extend ActiveSupport::Concern

        included do
          helper_method :clone_taxonmies
        end

        def clone_taxonmies(source_store_id, target_store_id)
          taxonomies = get_taxonomies source_store_id
          taxonomies.each { |taxonomy| clone_taxonomy(taxonomy, target_store_id) }
        end

        def get_taxonomies(store_id)
          Spree::Taxonomy.where(store_id: store_id)
        end

        def get_cloned_taxonomies(taxonomies, target_store_id)
          taxonomies.map { |taxonomy| update_taxonomy(taxonomy, target_store_id) }
        end

        def clone_taxonomy(taxonomy, target_store_id)
          cloned_taxonomy = taxonomy.dup
          cloned_taxonomy.assign_attributes(store_id: target_store_id)
          if cloned_taxonomy.save
            clone_taxons(taxonomy.id, cloned_taxonomy.id)
          else
            render_error_payload(taxonomy.errors)
          end
        end
      end
    end
  end
end
