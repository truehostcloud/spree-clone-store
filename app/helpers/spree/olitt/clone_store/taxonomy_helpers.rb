module Spree
  module Olitt
    module CloneStore
      module TaxonomyHelpers
        extend ActiveSupport::Concern

        included do
          helper_method :clone_taxonmies
        end

        def clone_taxonmies
          taxonomies = Spree::Taxonomy.where(store_id: source_id_param)
          taxonomies = taxonomies.map { |taxonomy| clone_taxonomy taxonomy }
          taxonomies.each { |taxonomy| render_error_payload(taxonomy.errors) unless taxonomy.save }
          render json: taxonomies
        end

        private

        def clone_taxonomy(taxonomy)
          cloned_taxonomy = taxonomy.dup
          cloned_taxonomy.assign_attributes(store_id: @store.id)
          cloned_taxonomy
        end
      end
    end
  end
end
