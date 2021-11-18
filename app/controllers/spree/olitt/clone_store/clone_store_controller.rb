# require_dependency 'spree/olitt/clone_store/taxonomy_helpers'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers
        attr_accessor :old_store, :new_store

        # For Testing Only
        def test
          @old_store = Spree::Store.find_by(id: source_id_param)
          @new_store = Spree::Store.find_by(id: 6)
          handle_clone_taxons
          render json: @new_store.taxons.all
        end

        def clone
          return unless handle_clone_store

          finish
        end

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

        # Taxonomies

        def handle_clone_taxonomies
          taxonomies = @old_store.taxonomies.all
          cloned_taxonomies = @new_store.taxonomies.build(get_model_hash(taxonomies))
          return false unless save_models(cloned_taxonomies)

          true
        end

        # Taxons

        def handle_clone_taxons
          old_root_taxons = @old_store.taxons.where(parent: nil)
          old_root_taxons.each { |root_taxon| clone_taxon(root_taxon) }
        end

        def clone_taxon(parent_taxon)
          old_taxons = @old_store.taxons.where(parent: parent_taxon, taxonomy: parent_taxon.taxonomy)
          return if old_taxons.nil?

          new_taxonomy = @new_store.taxonomies.find_by(name: parent_taxon.taxonomy.name)
          cloned_taxons = clone_update_taxon(old_taxons, new_taxonomy, get_new_root_taxon(new_taxonomy, parent_taxon))
          return false unless save_models(cloned_taxons)

          old_taxons.each { |taxon| clone_taxon(taxon) }
        end

        def clone_update_taxon(old_taxons, new_taxonomy, new_parent_taxon)
          taxons = old_taxons.map do |taxon|
            new_taxon = taxon.dup
            new_taxon.parent = new_parent_taxon
            new_taxon
          end
          taxons = get_model_hash(taxons).map do |taxon|
            taxon.except('lft', 'rgt', 'depth')
          end
          new_taxonomy.taxons.build(taxons)
        end

        def get_new_root_taxon(new_taxonomy, old_parent_taxon)
          @new_store.taxons.find_by(permalink: old_parent_taxon.permalink, taxonomy: new_taxonomy)
        end

        # finish lifecycle

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
