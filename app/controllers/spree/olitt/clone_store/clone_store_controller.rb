require_relative 'duplicators/linked_resource_duplicator'
require_relative 'duplicators/menu_items_duplicator'
require_relative 'duplicators/menus_duplicator'
require_relative 'duplicators/pages_duplicator'
require_relative 'duplicators/products_duplicator'
require_relative 'duplicators/sections_duplicator'
require_relative 'duplicators/taxonomies_duplicator'
require_relative 'duplicators/taxons_duplicator'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers
        include Spree::Olitt::CloneStore::ProductHelpers
        attr_accessor :old_store, :new_store

        def clone
          # return unless handle_clone_store

          @old_store = Spree::Store.includes(:taxonomies, :taxons, :menus, :menu_items, :cms_pages, :cms_sections,
                                             products: %i[variants taxons product_properties master])
                                   .find_by(id: source_id_param)
          @new_store = Spree::Store.find_by(id: 4)

          return unless Spree::Olitt::CloneStore::Duplicators::TaxonomiesDuplicator.new(old_store: @old_store,
                                                                                        new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::TaxonsDuplicator.new(old_store: @old_store,
                                                                                    new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::MenusDuplicator.new(old_store: @old_store,
                                                                                   new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::MenuItemsDuplicator.new(old_store: @old_store,
                                                                                       new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::TaxonsDuplicator.new(old_store: @old_store,
                                                                                    new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::PagesDuplicator.new(old_store: @old_store,
                                                                                   new_store: @new_store)
          return unless Spree::Olitt::CloneStore::Duplicators::SectionsDuplicator.new(old_store: @old_store,
                                                                                      new_store: @new_store)

          finish
        end

        # Store
        def handle_clone_store
          @old_store = Spree::Store.includes(:taxonomies, :taxons, :menus, :menu_items, :cms_pages, :cms_sections,
                                             products: %i[variants taxons product_properties master])
                                   .find_by(id: source_id_param)
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

        # Finish Lifecycle

        def finish
          render_serialized_payload(201) { serialize_resource(@new_store) }
        end
      end
    end
  end
end
