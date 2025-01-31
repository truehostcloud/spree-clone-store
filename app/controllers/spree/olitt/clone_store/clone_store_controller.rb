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

        def clone_store
          ActiveRecord::Base.transaction do
            return unless handle_clone_store

            linked_resource = Duplicators::LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)

            # Taxonomies
            taxonomies_duplicator = Duplicators::TaxonomiesDuplicator.new(old_store: @old_store,
                                                                          new_store: @new_store,
                                                                          vendor: @vendor)
            taxonomies_duplicator.handle_clone_taxonomies

            return render_error(duplicator: taxonomies_duplicator) if taxonomies_duplicator.errors_are_present?

            # Taxons
            taxon_duplicator = Duplicators::TaxonsDuplicator.new(old_store: @old_store,
                                                                 new_store: @new_store,
                                                                 vendor: @vendor,
                                                                 taxonomies_cache: taxonomies_duplicator.taxonomies_cache,
                                                                 root_taxons: taxonomies_duplicator.root_taxons)
            taxon_duplicator.handle_clone_taxons

            return render_error(duplicator: taxon_duplicator) if taxon_duplicator.errors_are_present?

            linked_resource.taxons_cache = taxon_duplicator.taxons_cache

            # Pages
            page_duplicator = Duplicators::PagesDuplicator.new(old_store: @old_store,
                                                               new_store: @new_store,
                                                                vendor: @vendor,
                                                               )
            page_duplicator.handle_clone_pages

            return render_error(duplicator: page_duplicator) if page_duplicator.errors_are_present?

            linked_resource.pages_cache = page_duplicator.pages_cache

            # Products
            product_duplicator = Duplicators::ProductsDuplicator.new(old_store: @old_store,
                                                                     new_store: @new_store,
                                                                     vendor: @vendor,
                                                                     taxon_cache: taxon_duplicator.taxons_cache)
            product_duplicator.handle_clone_products

            return render_error(duplicator: product_duplicator) if product_duplicator.errors_are_present?

            linked_resource.products_cache = product_duplicator.products_cache

            # Sections
            section_duplicator = Duplicators::SectionsDuplicator.new(old_store: @old_store,
                                                                     new_store: @new_store,
                                                                     vendor: @vendor,
                                                                     pages_cache: page_duplicator.pages_cache,
                                                                     linked_resource: linked_resource)
            section_duplicator.handle_clone_sections

            return render_error(duplicator: section_duplicator) if section_duplicator.errors_are_present?

            # Menus
            menus_duplicator = Duplicators::MenusDuplicator.new(old_store: @old_store,
                                                                new_store: @new_store)
            menus_duplicator.handle_clone_menus

            return render_error(duplicator: menus_duplicator) if menus_duplicator.errors_are_present?

            # Menu Items
            menu_items_duplicator = Duplicators::MenuItemsDuplicator.new(old_store: @old_store,
                                                                         new_store: @new_store,
                                                                         new_menus_cache: menus_duplicator.menus_cache,
                                                                         root_menu_items: menus_duplicator.root_menu_items,
                                                                         linked_resource: linked_resource)
            menu_items_duplicator.handle_clone_menu_items

            # Payment methods
            payment_methods_duplicator = Duplicators::PaymentMethodsDuplicator.new(new_store: @new_store, vendor: @vendor)
            payment_methods_duplicator.duplicate

            # Shipping methods
            shipping_methods_duplicator = Duplicators::ShippingMethodsDuplicator.new(vendor: @vendor, new_store: @new_store)
            shipping_methods_duplicator.duplicate

            return render_error(duplicator: menu_items_duplicator) if menu_items_duplicator.errors_are_present?

            finish
          end
        end

        def render_error(duplicator:)
          render json: duplicator.errors
          raise ActiveRecord::Rollback
        end

        def handle_create_vendor(email, password, password_confirmation)
          @vendor = Spree::Vendor.new(
            name: email,
            notification_email: email,
            state: 'active'
          )
          @vendor.save!
          # add vendor to user
          user = Spree::User.find_by(email: email)
          if user.nil?
            user = Spree::User.new(
              email: email,
              password: password,
              password_confirmation: password_confirmation,
            )
            user.save
            user.vendor_ids = [@vendor.id]
            user.save!
          end
        end

        # Store
        def handle_clone_store
          @old_store = Spree::Store.find_by(id: source_id_param)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          @vendor = Spree::Vendor.find_by(name: vendor_params[:email])
          if @vendor.nil?
            handle_create_vendor(
              vendor_params[:email],
              vendor_params[:password],
              vendor_params[:password_confirmation]
            )
          end

          store = clone_and_update_store @old_store.dup
          store.logo.attach(@old_store.logo.attachment.blob) if @old_store&.logo&.attachment&.attached?
          store.mailer_logo.attach(@old_store.mailer_logo.attachment.blob) if @old_store&.mailer_logo&.attachment&.attached?
          store.favicon_image.attach(@old_store.favicon_image.attachment.blob) if @old_store&.favicon_image&.attachment&.attached?

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
          store.customer_support_email = mail_from_address
          store.new_order_notifications_email = mail_from_address
          store.default = false
          store.vendor = @vendor
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
