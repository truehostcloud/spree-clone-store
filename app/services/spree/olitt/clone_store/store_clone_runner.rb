require_relative 'duplicators/linked_resource_duplicator'
require_relative 'duplicators/menu_items_duplicator'
require_relative 'duplicators/menus_duplicator'
require_relative 'duplicators/pages_duplicator'
require_relative 'duplicators/payment_methods_duplicator'
require_relative 'duplicators/products_duplicator'
require_relative 'duplicators/sections_duplicator'
require_relative 'duplicators/shipping_methods_duplicator'
require_relative 'duplicators/taxonomies_duplicator'
require_relative 'duplicators/taxons_duplicator'

module Spree
  module Olitt
    module CloneStore
      class StoreCloneRunner
        attr_reader :errors

        def initialize(old_store:, new_store:, vendor:)
          @old_store = old_store
          @new_store = new_store
          @vendor = vendor
          @errors = []
        end

        def call
          ActiveRecord::Base.transaction do
            linked_resource = Duplicators::LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)

            taxonomies_duplicator = Duplicators::TaxonomiesDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor
            )
            taxonomies_duplicator.handle_clone_taxonomies
            rollback_with_errors!(taxonomies_duplicator.errors) if taxonomies_duplicator.errors_are_present?

            taxon_duplicator = Duplicators::TaxonsDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor,
              taxonomies_cache: taxonomies_duplicator.taxonomies_cache,
              root_taxons: taxonomies_duplicator.root_taxons
            )
            taxon_duplicator.handle_clone_taxons
            rollback_with_errors!(taxon_duplicator.errors) if taxon_duplicator.errors_are_present?
            linked_resource.taxons_cache = taxon_duplicator.taxons_cache

            page_duplicator = Duplicators::PagesDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor
            )
            page_duplicator.handle_clone_pages
            rollback_with_errors!(page_duplicator.errors) if page_duplicator.errors_are_present?
            linked_resource.pages_cache = page_duplicator.pages_cache

            product_duplicator = Duplicators::ProductsDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor,
              taxon_cache: taxon_duplicator.taxons_cache
            )
            product_duplicator.handle_clone_products
            rollback_with_errors!(product_duplicator.errors) if product_duplicator.errors_are_present?
            linked_resource.products_cache = product_duplicator.products_cache

            section_duplicator = Duplicators::SectionsDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor,
              pages_cache: page_duplicator.pages_cache,
              linked_resource: linked_resource
            )
            section_duplicator.handle_clone_sections
            rollback_with_errors!(section_duplicator.errors) if section_duplicator.errors_are_present?

            menus_duplicator = Duplicators::MenusDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor
            )
            menus_duplicator.handle_clone_menus
            rollback_with_errors!(menus_duplicator.errors) if menus_duplicator.errors_are_present?

            menu_items_duplicator = Duplicators::MenuItemsDuplicator.new(
              old_store: @old_store,
              new_store: @new_store,
              vendor: @vendor,
              new_menus_cache: menus_duplicator.menus_cache,
              root_menu_items: menus_duplicator.root_menu_items,
              linked_resource: linked_resource
            )
            menu_items_duplicator.handle_clone_menu_items
            rollback_with_errors!(menu_items_duplicator.errors) if menu_items_duplicator.errors_are_present?

            Duplicators::PaymentMethodsDuplicator.new(new_store: @new_store, vendor: @vendor).duplicate
            Duplicators::ShippingMethodsDuplicator.new(vendor: @vendor, new_store: @new_store).duplicate

            attach_store_images
          end

          errors.blank?
        end

        private

        def attach_store_images
          if @old_store&.logo&.attachment&.attached?
            @new_store.build_logo
            @new_store.logo.attachment.attach(@old_store.logo.attachment.blob)
          end
          if @old_store&.mailer_logo&.attachment&.attached?
            @new_store.build_mailer_logo
            @new_store.mailer_logo.attachment.attach(@old_store.mailer_logo.attachment.blob)
          end
          if @old_store&.favicon_image&.attachment&.attached?
            @new_store.build_favicon_image
            @new_store.favicon_image.attachment.attach(@old_store.favicon_image.attachment.blob)
          end

          @new_store.save!
        end

        def rollback_with_errors!(duplicator_errors)
          @errors = normalize_errors(duplicator_errors)
          raise ActiveRecord::Rollback
        end

        def normalize_errors(raw_errors)
          Array(raw_errors).flatten.compact.flat_map do |error|
            next error.full_messages if error.respond_to?(:full_messages)

            error.to_s
          end
        end
      end
    end
  end
end