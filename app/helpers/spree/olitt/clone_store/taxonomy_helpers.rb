module Spree
  module Olitt
    module CloneStore
      module TaxonomyHelpers
        def clone_taxonmies
          taxonomies = Spree::Store.find_by(id: source_id_param)
          render json: taxonomies
        end
      end
    end
  end
end
