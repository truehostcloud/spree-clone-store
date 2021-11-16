# require_dependency 'spree/olitt/clone_store/taxonomy_helpers'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        # For Testing Only
        def test
          # @old_store = Spree::Store.find_by(id: store_id)
          # @new_store = Spree::Store.find_by(id: 6)
          # new_taxonomy = @new_store.taxonomies.find_by(id: 20)
          # clone_taxons(new_taxonomy)
          get_old_store

        end

        def clone
          return unless handle_clone_store

          finish
        end

        private

        attr_accessor :old_store, :new_store

        # Store

        def get_old_store
          @old_store = Spree::Store.find_by(id: store_id)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          # store = clone_and_update_store @old_store.dup

          unless store.save
            render_error_payload(@store.errors)
            return false
          end

          # @new_store = store

          render json: { success: true, data: store }

        end

        def setup_new_store(store)
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

        def clone_taxonomies
          taxonomies = @old_store.taxonomies.all
          cloned_taxonomies = @new_store.taxonomies.build(get_model_hash(taxonomies))
          save_models(cloned_taxonomies)
          cloned_taxonomies.each do |taxonomy|
            break unless clone_taxons(taxonomy)
          end
        end

        # Taxons

        def clone_taxons(taxonomy)
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

        # menus

        def clone_menus
          menus = @old_store.menus.all
          raise ActiveRecord::RecordNotFound if menus.nil?
          cloned_menus =  @new_store.menus.build(get_model_hash(menus))
          save_models(cloned_menus)
        end

        #  menu items
        def clone_menu_items
          menu_items = @old_store.menu_items.all
          raise ActiveRecord::RecordNotFound if menu_items.nil?
          cloned_menu_items =  @new_store.menu_items.build(get_model_hash(menu_items))
          save_models(cloned_menu_items)
        end

        # Product

        def clone_products
          clone_option_types
          clone_prototypes
          clone_variants
          products = @old_store.products.all
          cloned_products = @new_store.products.build(get_model_hash(products))
          save_models(cloned_products)
        end

        # products variants

        def clone_variants
          variants = @old_store.variants.all
          raise ActiveRecord::RecordNotFound if variants.nil?
          cloned_variants = @new_store.products.build(get_model_hash(variants))
          save_models(cloned_variants)
        end

        # products option types

        def clone_option_types
          raise ActiveRecord::RecordNotFound if @old_store.option_types.all?

          @option_types = @old_store.option_types.all

          cloned_option_types = @new_store.option_type.option_values.build(get_model_hash(option_types))
          save_models(cloned_option_types)
        end

        # cms pages

        def clone_cms_page
          cms_page = @old_store.cms_pages.all
          cloned_cms_pages = @new_store.cms_pages.build(get_model_hash(cms_page))
          save_models(cloned_cms_pages)
        end

        # cms sections

        def clone_cms_sections
          cms_sections = @old_store.cms_sections.all
          cloned_cms_section = @new_store.cms_sections.build(get_model_hash(cms_sections))
          save_models(cloned_cms_section)
        end


        # finish lifecycle

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
