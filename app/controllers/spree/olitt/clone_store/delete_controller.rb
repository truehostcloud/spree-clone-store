module Spree
  module Olitt
    module CloneStore
      class DeleteController < Spree::Api::V2::BaseController
        def taxonomies
          old_taxonomies = get_store.taxonomies

          destroy(models: old_taxonomies)

          render json: old_taxonomies
        end

        def taxons
          old_taxons = get_store.taxons

          destroy(models: old_taxons)

          render json: old_taxons
        end

        private

        def get_store
          Spree::Store.find_by(id: 6)
        end

        def destroy(models:)
          models.each(&:destroy)
        end
      end
    end
  end
end
