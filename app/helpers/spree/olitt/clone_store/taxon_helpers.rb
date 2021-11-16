module Spree
  module Olitt
    module CloneStore
      module TaxonHelpers
        extend ActiveSupport::Concern

        included do
          helper_method :clone_taxons
        end

        def clone_taxons(source_taxonomy_id, target_taxonomy_id)
          taxons = Spree::Taxon.where(taxonomy_id: source_taxonomy_id)
          taxons = taxons.map { |taxon| clone_taxon(taxon, target_taxonomy_id) }
          taxons.each do |taxon|
            next if taxon.save

            render_error_payload(taxon.errors)
            break
          end
        end

        def clone_taxon(taxon, taxonomy_id)
          cloned_taxon = taxon.dup
          cloned_taxon.assign_attributes(taxonomy_id: taxonomy_id)
          cloned_taxon
        end
      end
    end
  end
end
