# require_dependency 'spree/olitt/clone_store/taxonomy_helpers'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController # rubocop:disable Metrics/ClassLength
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        

        # For Testing Only
        def test
          @old_store = Spree::Store.find_by(id: source_id_param)
          clone
        end

        def clone
          handle_clone_store
          handle_clone_taxonomies

          finish
        rescue StandardError => e
          Rails.logger.error(e.message)
          # render json: e.message
        end

        # Store
        def handle_clone_store
          @old_store = Spree::Store.find_by(id: source_id_param)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          store = clone_and_update_store @old_store.dup
          store.save
          @new_store = store
        end

        def clone_and_update_store(store)
          name, url, code, mail_from_address = required_store_params

          store.name = name
          store.url = url
          store.code = code
          store.mail_from_address = mail_from_address
        end

        # Taxonomies

        def handle_clone_taxonomies
          taxonomies = @old_store.taxonomies.all
          cloned_taxonomies = @new_store.taxonomies.build(get_model_hash(taxonomies))
          save_models(cloned_taxonomies)
        end

        # Taxons

        def handle_clone_taxons
          taxonomies = @new_store.taxonomies.all
          taxonomies.each { |taxonomy| clone_taxon(taxonomy) }
        end

        def clone_taxon(taxonomy)
          root_taxons = @old_store.taxonomies.find_by(name: taxonomy.name).taxons.where(parent: nil)
          cloned_root_taxons = clone_update_root_taxon(root_taxons, taxonomy)
          save_models(cloned_root_taxons)

          # root_taxons.each do |root_taxon|
          # end

          # all_old_taxons = @old_store.taxonomies.find_by(name: taxonomy.name).taxons.order(:id)

          # all_old_taxons.each do |_old_parent_taxon|
          #   old_child_taxons = taxonomy.taxons
          #   clone_update_child_taxon(old_child_taxons, _old_parent_taxon)
          # end
        end

        def clone_update_root_taxon(root_taxons, taxonomy)
          taxons = root_taxons.map do |taxon|
            taxon.taxonomy = taxonomy
            taxon
          end
          taxons = get_model_hash(taxons)
          taxons = taxons.map do |taxon|
            taxon.except('lft', 'rgt', 'depth')
          end
          taxonomy.taxons.build(taxons)
        end

        def clone_update_child_taxon(child_taxons, taxonomy)
          taxons = child_taxons.map do |taxon|
            taxon.taxonomy = taxonomy
            taxon
          end
          taxons = get_model_hash(taxons)
          taxons = taxons.map do |taxon|
            taxon.except('lft', 'rgt', 'depth')
          end
          taxonomy.taxons.build(taxons)
        end

        # Menus

        def clone_menus
          menus = @old_store.menus.all
          raise ActiveRecord::RecordNotFound if menus.nil?

          cloned_menus = @new_store.menus.build(get_model_hash(menus))
          save_models(cloned_menus)
        end

        # Menu items
        def clone_menu_items
          menu_items = @old_store.menu_items.all
          raise ActiveRecord::RecordNotFound if menu_items.nil?

          cloned_menu_items = @new_store.menu_items.build(get_model_hash(menu_items))
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

        # Products variants

        def clone_variants
          variants = @old_store.variants.all
          raise ActiveRecord::RecordNotFound if variants.nil?

          cloned_variants = @new_store.products.build(get_model_hash(variants))
          save_models(cloned_variants)
        end

        # Products Option Types

        def clone_option_types
          raise ActiveRecord::RecordNotFound if @old_store.option_types.all?

          @option_types = @old_store.option_types.all

          cloned_option_types = @new_store.option_type.option_values.build(get_model_hash(@option_types))
          save_models(cloned_option_types)
        end

        # CMS Pages

        def clone_cms_page
          cms_page = @old_store.cms_pages.all
          cloned_cms_pages = @new_store.cms_pages.build(get_model_hash(cms_page))
          save_models(cloned_cms_pages)
        end

        # CMS Sections

        def clone_cms_sections
          cms_sections = @old_store.cms_sections.all
          cloned_cms_section = @new_store.cms_sections.build(get_model_hash(cms_sections))
          save_models(cloned_cms_section)
        end

        # Finish lifecycle

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
