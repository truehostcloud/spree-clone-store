# require_dependency 'spree/olitt/clone_store/taxonomy_helpers'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        # For Testing Only
        def test
          @old_store = Spree::Store.find_by(id: source_id_param)
          @new_store = Spree::Store.find_by(id: 6)
          new_taxonomy = @new_store.taxonomies.find_by(id: 20)
          handle_clone_taxons(new_taxonomy)
        end

        def clone
          return unless handle_clone_store

          finish
        end

        private

        attr_accessor :old_store, :new_store

        # Store
        def handle_clone_store
          @old_store = Spree::Store.find_by(id: source_id_param)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          store = clone_and_update_store @old_store.dup

          unless store.save
            render_error_payload(@store.errors)
            return false
          end

          @new_store = store
          true
        end

        def clone_and_update_store(store)
          name, url, code, mail_from_address = required_store_params

          store.name = name
          store.url = url
          store.code = code
          store.mail_from_address = mail_from_address
          store
        end

        def required_store_params
          name, url, code, mail_from_address = store_params.values_at(:name, :url, :code, :mail_from_address)

          raise ActionController::ParameterMissing, :name if name.nil?
          raise ActionController::ParameterMissing, :url if url.nil?
          raise ActionController::ParameterMissing, :code if code.nil?
          raise ActionController::ParameterMissing, :mail_from_address if mail_from_address.nil?

          [name, url, code, mail_from_address]
        end

        # Taxonomies

        def handle_clone_taxonomies
          taxonomies = @old_store.taxonomies.all
          cloned_taxonomies = @new_store.taxonomies.build(get_model_hash(taxonomies))
          save_models(cloned_taxonomies)
          cloned_taxonomies.each do |taxonomy|
            break unless handle_clone_taxons(taxonomy)
          end
        end

        # Taxons

        def handle_clone_taxons(taxonomy)
          root_taxons = @old_store.taxonomies.find_by(name: taxonomy.name).taxons.where(parent: nil)
          cloned_root_taxons = clone_update_taxon(root_taxons, taxonomy)
          return false unless save_models(cloned_root_taxons)

          true
        end

        def clone_update_taxon(root_taxons, taxonomy)
          taxons = root_taxons.map do |taxon|
            taxon.taxonomy_id = taxonomy.id
            taxon
          end
          taxons = get_model_hash(taxons)
          taxons = taxons.map do |taxon|
            taxon.except('lft', 'rgt', 'depth')
          end
          taxonomy.taxons.build(taxons)
        end

        # finish lifecylec

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
