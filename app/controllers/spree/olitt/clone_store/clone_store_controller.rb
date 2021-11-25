module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers
        include Spree::Olitt::CloneStore::ProductHelpers
        attr_accessor :old_store, :new_store

        def clone
          return unless handle_clone_store
          return unless handle_clone_taxonomies
          # return unless handle_clone_taxons
          return unless handle_clone_menus
          # return unless handle_clone_menu_items
          return unless handle_clone_pages
          # return unless handle_clone_sections
          return unless handle_clone_products

          finish
        end

        # Store
        def handle_clone_store
          @old_store = Spree::Store.find_by(id: source_id_param)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          store = clone_and_update_store @old_store.dup

          unless store.save
            render_error_payload(store.errors)
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
          old_root_taxons = @old_store.taxons.where(parent: nil).order(depth: :asc).order(id: :asc)
          old_root_taxons.each { |root_taxon| return false unless clone_taxon(root_taxon, terminate: false) }
          true
        end

        def clone_taxon(parent_taxon, terminate: false)
          return false if terminate

          old_taxons = @old_store.taxons.where(parent: parent_taxon, taxonomy: parent_taxon.taxonomy)
                                 .order(depth: :asc).order(id: :asc)
          return false if old_taxons.nil?

          new_taxonomy = @new_store.taxonomies.find_by(name: parent_taxon.taxonomy.name)
          new_parent_taxon = get_new_parent_taxon(new_taxonomy, parent_taxon)

          cloned_taxons = clone_update_taxon(old_taxons, new_taxonomy, new_parent_taxon)
          terminate = true unless save_models(cloned_taxons)

          old_taxons.each { |taxon| return false unless clone_taxon(taxon, terminate: terminate) }
          true
        end

        def clone_update_taxon(old_taxons, new_taxonomy, new_parent_taxon)
          taxons = old_taxons.map do |taxon|
            new_taxon = taxon.dup
            new_taxon.parent = new_parent_taxon
            new_taxon
          end
          attributes_for_each_taxon = get_model_hash(taxons).map do |attributes|
            attributes.except('lft', 'rgt', 'depth')
          end
          new_taxonomy.taxons.build(attributes_for_each_taxon)
        end

        def get_new_parent_taxon(new_taxonomy, old_parent_taxon)
          @new_store.taxons.find_by(permalink: old_parent_taxon.permalink, taxonomy: new_taxonomy)
        end

        # Menus
        def handle_clone_menus
          menus = @old_store.menus.all
          cloned_menus = @new_store.menus.build(get_model_hash(menus))
          return false unless save_models(cloned_menus)

          true
        end

        # Menu Items
        def handle_clone_menu_items
          old_root_menu_items = @old_store.menu_items.where(parent: nil).order(depth: :asc).order(id: :asc)
          old_root_menu_items.each do |root_menu_item|
            return false unless clone_menu_item(parent_menu_item: root_menu_item,
                                                terminate: false)
          end
          true
        end

        def clone_menu_item(parent_menu_item:, terminate: false)
          return false if terminate

          old_menu_items = @old_store.menu_items.where(parent: parent_menu_item, menu: parent_menu_item.menu)
                                     .order(depth: :asc).order(id: :asc)
          return false if old_menu_items.nil?

          cloned_menu_items = clone_menu_item_helper(old_menu_items: old_menu_items, parent_menu_item: parent_menu_item)

          terminate = true unless save_models(cloned_menu_items)

          old_menu_items.each { |menu_item| return false unless clone_menu_item(parent_menu_item: menu_item, terminate: terminate) }
          true
        end

        def clone_menu_item_helper(old_menu_items:, parent_menu_item:)
          new_menu = @new_store.menus.find_by(location: parent_menu_item.menu.location, locale: parent_menu_item.menu.locale)
          new_parent_menu_item = get_new_parent_menu_item(new_menu: new_menu, old_parent_menu_item: parent_menu_item)

          clone_update_menu_item(old_menu_items: old_menu_items,
                                 new_menu: new_menu, new_parent_menu_item: new_parent_menu_item)
        end

        def clone_update_menu_item(old_menu_items:, new_menu:, new_parent_menu_item:)
          menu_items = old_menu_items.map do |menu_item|
            new_menu_item = menu_item.dup
            new_menu_item.parent = new_parent_menu_item
            new_menu_item
          end
          attributes_for_each_taxon = get_model_hash(menu_items).map do |attributes|
            attributes.except('lft', 'rgt', 'depth')
          end
          new_menu.menu_items.build(attributes_for_each_taxon)
        end

        def get_new_parent_menu_item(new_menu:, old_parent_menu_item:)
          old_grandparent_menu_item = old_parent_menu_item.parent
          new_grandparent_menu_item = nil
          unless old_grandparent_menu_item.nil?
            new_grandparent_menu_item = @new_store.menu_items.joins(:menu).find_by(menu: new_menu,
                                                                                   name: old_grandparent_menu_item.name)

          end

          @new_store.menu_items.joins(:menu).find_by(menu: new_menu, name: old_parent_menu_item.name, parent: new_grandparent_menu_item)
        end

        def get_new_menu_item_linked_resource(resource_type:, resource_id:)
          resource = resource_type.constantize
          old_linked_resource = resource.find_by(id: resource_id)

          return get_new_linked_taxon(old_taxon: old_linked_resource) if old_linked_resource.instance_of?('Spree::Taxon'.constantize)

          return get_new_linked_product(old_product: old_linked_resource) if old_linked_resource.instance_of?('Spree::Product'.constantize)

          return get_new_linked_page(old_page: old_linked_resource) if old_linked_resource.instance_of?('Spree::CmsPage'.constantize)

          nil
        end

        # Pages
        def handle_clone_pages
          pages = @old_store.cms_pages.all
          cloned_pages = @new_store.cms_pages.build(get_model_hash(pages))
          return false unless save_models(cloned_pages)

          true
        end

        # Sections
        def handle_clone_sections
          old_sections = @old_store.cms_sections.all
          new_sections = old_sections.map { |section| add_new_page_to_section(old_section: section) }
          new_sections = new_sections.map { |section| add_linked_resource_to_section(old_section: section) }
          return false unless save_models(new_sections)

          true
        end

        def add_new_page_to_section(old_section:)
          new_page = @new_store.cms_pages.find_by(slug: old_section.cms_page.slug)
          new_section = old_section.dup
          new_section.cms_page = new_page
          new_section
        end

        def add_linked_resource_to_section(old_section:)
          return old_section unless old_section.methods.include? :linked_resource_type
          return old_section if old_section.linked_resource_type.nil?

          new_resource_id = get_new_section_linked_resource(resource_id: old_section.linked_resource_id,
                                                            resource_type: old_section.linked_resource_type)

          return reset_section_resource(section: old_section) if new_resource_id.nil?

          old_section.linked_resource_id = new_resource_id
          old_section
        end

        def get_new_section_linked_resource(resource_id:, resource_type:)
          resource = resource_type.constantize
          old_linked_resource = resource.find_by(id: resource_id)

          return get_new_linked_taxon(old_taxon: old_linked_resource) if old_linked_resource.instance_of?('Spree::Taxon'.constantize)

          return get_new_linked_product(old_product: old_linked_resource) if old_linked_resource.instance_of?('Spree::Product'.constantize)

          nil
        end

        def reset_section_resource(section:)
          section.linked_resource_id = nil
          section.linked_resource_type = nil
          section
        end

        # Products
        def handle_clone_products
          old_products = @old_store.products.all
          new_products = old_products.map { |product| clone_product(old_product: product) }

          return false unless save_models(new_products)

          true
        end

        def clone_product(old_product:)
          old_product.dup.tap do |new_product|
            new_product.taxons = old_product.taxons.all.map { |old_taxon| @new_store.taxons.find_by(permalink: old_taxon.permalink) }
            new_product.stores = [@new_store]
            new_product.created_at = nil
            new_product.deleted_at = nil
            new_product.updated_at = nil
            new_product.product_properties = reset_properties(product: old_product)
            new_product.master = duplicate_master_variant(product: old_product)
            new_product.variants = old_product.variants.map { |variant| duplicate_variant(variant: variant) }
          end
        end

        # Linked Resources
        def get_new_linked_taxon(old_taxon:)
          if old_taxon.instance_of?('Spree::Taxon'.constantize)
            new_taxon = @new_store.taxons.find_by(permalink: old_taxon.permalink)
            return new_taxon.id
          end
          nil
        end

        def get_new_linked_product(old_product:)
          if old_product.instance_of?('Spree::Product'.constantize)
            new_product = @new_store.products.find_by(slug: old_product.slug)
            return new_product.id
          end
          nil
        end

        def get_new_linked_page(old_page:)
          if old_page.instance_of?('Spree::CmsPage'.constantize)
            new_page = @new_store.cms_pages.find_by(slug: old_page.slug)
            return new_page.id
          end
          nil
        end

        # Finish Lifecycle

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
