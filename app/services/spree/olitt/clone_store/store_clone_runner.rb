require_relative 'duplicators/linked_resource_duplicator'
require_relative 'duplicators/menu_items_duplicator'
require_relative 'duplicators/menus_duplicator'
require_relative 'duplicators/option_types_duplicator'
require_relative 'duplicators/pages_duplicator'
require_relative 'duplicators/payment_methods_duplicator'
require_relative 'duplicators/products_duplicator'
require_relative 'duplicators/sections_duplicator'
require_relative 'duplicators/shipping_categories_duplicator'
require_relative 'duplicators/shipping_methods_duplicator'
require_relative 'duplicators/stock_items_duplicator'
require_relative 'duplicators/stock_locations_duplicator'
require_relative 'duplicators/taxonomies_duplicator'
require_relative 'duplicators/taxons_duplicator'
require_relative 'duplicators/vendor_addresses_duplicator'
require_relative 'zone_resolver'

module Spree
  module Olitt
    module CloneStore
      class StoreCloneRunner
        SECTION_ERROR_PREFIX = '[spree_clone_store] clone section failed'.freeze

        attr_reader :errors

        def initialize(old_store:, new_store:, vendor:)
          @old_store = old_store
          @new_store = new_store
          @vendor = vendor
          @errors = []
        end

        def call
          linked_resource = Duplicators::LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)

          stock_locations_duplicator = Duplicators::StockLocationsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('stock locations', stock_locations_duplicator) { stock_locations_duplicator.handle_clone_stock_locations }

          vendor_addresses_duplicator = Duplicators::VendorAddressesDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            stock_locations_duplicator: stock_locations_duplicator
          )
          run_section('vendor addresses', vendor_addresses_duplicator) { vendor_addresses_duplicator.handle_clone_vendor_addresses }

          taxonomies_duplicator = Duplicators::TaxonomiesDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('taxonomies', taxonomies_duplicator) { taxonomies_duplicator.handle_clone_taxonomies }

          taxon_duplicator = Duplicators::TaxonsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            taxonomies_cache: taxonomies_duplicator.taxonomies_cache,
            root_taxons: taxonomies_duplicator.root_taxons
          )
          run_section('taxons', taxon_duplicator) { taxon_duplicator.handle_clone_taxons }
          linked_resource.taxons_cache = taxon_duplicator.taxons_cache

          page_duplicator = Duplicators::PagesDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('pages', page_duplicator) { page_duplicator.handle_clone_pages }
          linked_resource.pages_cache = page_duplicator.pages_cache

          shipping_categories_duplicator = Duplicators::ShippingCategoriesDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('shipping categories', shipping_categories_duplicator) do
            shipping_categories_duplicator.handle_clone_shipping_categories
          end

          option_types_duplicator = Duplicators::OptionTypesDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('option types', option_types_duplicator) do
            option_types_duplicator.handle_clone_option_types
          end

          product_duplicator = Duplicators::ProductsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            taxon_cache: taxon_duplicator.taxons_cache,
            shipping_category_cache: shipping_categories_duplicator.shipping_categories_cache,
            option_type_cache: option_types_duplicator.option_types_cache,
            option_value_cache: option_types_duplicator.option_values_cache
          )
          run_section('products', product_duplicator) { product_duplicator.handle_clone_products }
          linked_resource.products_cache = product_duplicator.products_cache

          stock_items_duplicator = Duplicators::StockItemsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            stock_locations_cache: stock_locations_duplicator.locations_cache,
            variants_cache: product_duplicator.variants_cache
          )
          run_section('stock items', stock_items_duplicator) { stock_items_duplicator.handle_clone_stock_items }

          section_duplicator = Duplicators::SectionsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            pages_cache: page_duplicator.pages_cache,
            linked_resource: linked_resource
          )
          run_section('sections', section_duplicator) { section_duplicator.handle_clone_sections }

          menus_duplicator = Duplicators::MenusDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor
          )
          run_section('menus', menus_duplicator) { menus_duplicator.handle_clone_menus }

          menu_items_duplicator = Duplicators::MenuItemsDuplicator.new(
            old_store: @old_store,
            new_store: @new_store,
            vendor: @vendor,
            new_menus_cache: menus_duplicator.menus_cache,
            root_menu_items: menus_duplicator.root_menu_items,
            linked_resource: linked_resource
          )
          run_section('menu items', menu_items_duplicator) { menu_items_duplicator.handle_clone_menu_items }

          run_section('payment methods') do
            Duplicators::PaymentMethodsDuplicator.new(old_store: @old_store, new_store: @new_store, vendor: @vendor).duplicate
          end
          run_section('shipping methods') do
            Duplicators::ShippingMethodsDuplicator.new(
              old_store: @old_store,
              vendor: @vendor,
              new_store: @new_store,
              shipping_categories_cache: shipping_categories_duplicator.shipping_categories_cache,
              zone_resolver: ZoneResolver.new
            ).duplicate
          end
          run_section('store images') { attach_store_images }

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

        def run_section(section_name, duplicator = nil)
          yield
          errors.concat(normalize_errors(duplicator.errors)) if duplicator&.errors_are_present?
        rescue StandardError => e
          message = "#{SECTION_ERROR_PREFIX} section=#{section_name}: #{e.message}"
          @errors << message
          Rails.logger.error(message)
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