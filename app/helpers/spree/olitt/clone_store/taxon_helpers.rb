module Spree
  module Olitt
    module CloneStore
      module TaxonHelpers
        extend ActiveSupport::Concern

        included do
          helper_method :clone_taxons
        end

        def entry(source_taxonomy, _target_taxonomy_id)
          render json: source_taxonomy.taxons.where(parent: nil)
        end

        def clone_taxons(source_taxonomy_id, target_taxonomy_id)
          taxons = Spree::Taxon.where(taxonomy_id: source_taxonomy_id)
          cloned_taxons = taxons.map { |taxon| clone_taxon(taxon, target_taxonomy_id) }
          cloned_taxons.each do |taxon|
            taxon.save

            # render_error_payload(taxon.errors)
            render json: { error: taxon.errors.full_messages.to_sentence, errors: taxon.errors.messages, taxon: taxon }
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
