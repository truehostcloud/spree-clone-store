require 'json'

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
      class CloneStoreController < Spree::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        # skip_before_action :verify_authenticity_token, only: :clone_store, raise: false

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
                                                                new_store: @new_store,
                                                                vendor: @vendor)
            menus_duplicator.handle_clone_menus

            return render_error(duplicator: menus_duplicator) if menus_duplicator.errors_are_present?

            # Menu Items
            menu_items_duplicator = Duplicators::MenuItemsDuplicator.new(old_store: @old_store,
                                                                         new_store: @new_store,
                                                                         vendor: @vendor,
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

            attach_store_images

            finish
          end
        end

        def render_error(duplicator:)
          render_error_payload(duplicator.errors)
          raise ActiveRecord::Rollback
        end

        def handle_create_vendor(email, password, password_confirmation)
          user_email = email.to_s.strip.downcase
          @vendor = find_or_create_vendor(user_email)
          user = find_or_create_user(user_email, password, password_confirmation)
          assign_vendor_role(user, @vendor)
          activate_vendor(@vendor)
        end

        # Store
        def handle_clone_store
          @old_store = Spree::Store.find_by(id: source_id_param)
          raise ActiveRecord::RecordNotFound if @old_store.nil?

          @vendor = Spree::Vendor.find_by(notification_email: vendor_params[:email].to_s.strip.downcase) ||
                    Spree::Vendor.find_by(name: vendor_params[:email].to_s.strip.downcase)
          if @vendor.nil?
            handle_create_vendor(
              vendor_params[:email],
              vendor_params[:password],
              vendor_params[:password_confirmation]
            )
          end

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
          store.customer_support_email = mail_from_address
          store.new_order_notifications_email = mail_from_address
          store.default = false
          store.vendor_id = @vendor.id
          store.logo = nil
          store.mailer_logo = nil
          store.favicon_image = nil
          store
        end

        def attach_store_images
          store = @new_store
          if @old_store&.logo&.attachment&.attached?
            store.build_logo
            store.logo.attachment.attach(@old_store.logo.attachment.blob)
          end
          if @old_store&.mailer_logo&.attachment&.attached?
            store.build_mailer_logo
            store.mailer_logo.attachment.attach(@old_store.mailer_logo.attachment.blob)
          end
          if @old_store&.favicon_image&.attachment&.attached?
            store.build_favicon_image
            store.favicon_image.attachment.attach(@old_store.favicon_image.attachment.blob)
          end
          store.save
        end

        # Finish Lifecycle

        def finish
          @new_store.reload
          render json: serialize_store(@new_store), status: :created
        end

        private

        def find_or_create_vendor(email)
          ::Spree::Vendor.find_by(notification_email: email) ||
            ::Spree::Vendor.find_by(name: email) ||
            ::Spree::Vendor.create!(
              name: email,
              notification_email: email,
              contact_person_email: email,
              billing_email: email
            )
        end

        def find_or_create_user(email, password, password_confirmation)
          user = Spree.user_class.find_or_initialize_by(email: email)
          return user if user.persisted?

          user.password = password
          user.password_confirmation = password_confirmation.presence || password
          user.save!
          user
        end

        def assign_vendor_role(user, vendor)
          vendor_role_name = defined?(Spree::Vendor::DEFAULT_VENDOR_ROLE) ? Spree::Vendor::DEFAULT_VENDOR_ROLE : 'vendor'
          vendor_role = Spree::Role.find_or_create_by!(name: vendor_role_name)

          Spree::RoleUser.find_or_create_by!(
            user: user,
            role: vendor_role,
            resource: vendor
          )
        end

        def activate_vendor(vendor)
          return if %w[active approved].include?(vendor.state)

          vendor.start_onboarding! if vendor.respond_to?(:start_onboarding!) && vendor.state == 'invited'
          vendor.approve! if vendor.respond_to?(:approve!) && !%w[active approved].include?(vendor.state)
        end

        def render_error_payload(errors)
          render json: { errors: normalize_errors(errors) }, status: :unprocessable_entity
        end

        def normalize_errors(errors)
          Array(errors).flatten.compact.flat_map do |error|
            next error.full_messages if error.respond_to?(:full_messages)

            error.to_s
          end
        end

        def serialize_store(store)
          serializer = resource_serializer.new(store)
          return serializer.serializable_hash if serializer.respond_to?(:serializable_hash)

          serializer
        rescue StandardError
          {
            data: {
              id: store.id.to_s,
              type: 'store',
              attributes: {
                name: store.name,
                url: store.url,
                code: store.code,
                mail_from_address: store.mail_from_address
              }
            }
          }
        end
      end
    end
  end
end
