module Spree
  module Olitt
    module CloneStore
      class CloneRequestProvisioner
        attr_reader :errors

        def initialize(clone_request:)
          @clone_request = clone_request
          @errors = []
        end

        def call
          ActiveRecord::Base.transaction do
            source_store = @clone_request.source_store
            legacy_user = existing_legacy_user(@clone_request.vendor_email)
            vendor, created_vendor = find_or_create_vendor(@clone_request.vendor_email)
            admin_user, created_user = resolve_admin_user_for_vendor(
              vendor: vendor,
              email: @clone_request.vendor_email,
              password: @clone_request.vendor_password,
              legacy_user: legacy_user
            )
            role_user, created_role_user = assign_vendor_role(admin_user, vendor)
            link_admin_user_to_vendor!(vendor: vendor, admin_user: admin_user, legacy_user: legacy_user)

            activate_vendor(vendor)

            store = @clone_request.store || build_store(source_store: source_store, vendor: vendor)
            store.save! unless store.persisted?

            @clone_request.update!(
              store: store,
              vendor: vendor,
              admin_user: admin_user,
              role_user: role_user,
              created_vendor: @clone_request.created_vendor? || created_vendor,
              created_user: @clone_request.created_user? || created_user,
              created_role_user: @clone_request.created_role_user? || created_role_user
            )
          end

          true
        rescue ActiveRecord::RecordInvalid => e
          @errors = e.record.errors.full_messages.presence || [e.message]
          false
        rescue ActiveRecord::RecordNotUnique => e
          @errors = [extract_record_not_unique_message(e)]
          false
        rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing => e
          @errors = [e.message]
          false
        end

        private

        def build_store(source_store:, vendor:)
          store = source_store.dup
          store.name = @clone_request.store_name
          store.url = @clone_request.store_url
          store.code = @clone_request.store_code
          store.mail_from_address = @clone_request.store_mail_from_address
          store.customer_support_email = store.mail_from_address
          store.new_order_notifications_email = store.mail_from_address
          store.default = false
          store.vendor_id = vendor.id
          store.logo = nil
          store.mailer_logo = nil
          store.favicon_image = nil
          store
        end

        def find_or_create_vendor(email)
          vendor = existing_vendor(email)
          revive_vendor!(vendor) if vendor.present?
          return [vendor, false] if vendor.present?

          [
            ::Spree::Vendor.create!(
              name: email,
              notification_email: email,
              contact_person_email: email,
              billing_email: email
            ),
            true
          ]
        rescue ActiveRecord::RecordNotUnique
          vendor = existing_vendor(email)
          revive_vendor!(vendor) if vendor.present?
          return [vendor, false] if vendor.present?

          raise
        end

        def find_or_create_admin_user(email, password, legacy_user: nil)
          admin_user = build_admin_user(email)
          revive_admin_user!(admin_user) if admin_user.present?
          return [admin_user, false] if admin_user.persisted?

          configure_admin_user(admin_user, email, password, legacy_user)
          persist_admin_user(admin_user)
        rescue ActiveRecord::RecordNotUnique
          recover_existing_admin_user(email)
        end

        def build_admin_user(email)
          existing_admin_user(email) || Spree.admin_user_class.find_or_initialize_by(email: email)
        end

        def configure_admin_user(admin_user, email, password, legacy_user)
          admin_user.login ||= email if admin_user.respond_to?(:login=)
          admin_user.password = password
          admin_user.password_confirmation = password if admin_user.respond_to?(:password_confirmation=)
          copy_legacy_admin_user_attributes(admin_user, legacy_user)
        end

        def copy_legacy_admin_user_attributes(admin_user, legacy_user)
          return if legacy_user.blank?

          admin_user.first_name ||= legacy_user.first_name if admin_user.respond_to?(:first_name=)
          admin_user.last_name ||= legacy_user.last_name if admin_user.respond_to?(:last_name=)
          admin_user.selected_locale ||= legacy_user.selected_locale if admin_user.respond_to?(:selected_locale=)
        end

        def persist_admin_user(admin_user)
          admin_user.save!

          [admin_user, true]
        end

        def recover_existing_admin_user(email)
          admin_user = existing_admin_user(email)
          revive_admin_user!(admin_user) if admin_user.present?
          return [admin_user, false] if admin_user.present?

          raise
        end

        def assign_vendor_role(admin_user, vendor)
          vendor_role_name = defined?(Spree::Vendor::DEFAULT_VENDOR_ROLE) ? Spree::Vendor::DEFAULT_VENDOR_ROLE : 'vendor'
          vendor_role = vendor.respond_to?(:default_user_role) ? (vendor.default_user_role || Spree::Role.find_or_create_by!(name: vendor_role_name)) : Spree::Role.find_or_create_by!(name: vendor_role_name)
          role_user = Spree::RoleUser.find_by(user: admin_user, role: vendor_role, resource: vendor)
          return [role_user, false] if role_user.present?

          [Spree::RoleUser.create!(user: admin_user, role: vendor_role, resource: vendor), true]
        rescue ActiveRecord::RecordNotUnique
          role_user = Spree::RoleUser.find_by(user: admin_user, role: vendor_role, resource: vendor)
          return [role_user, false] if role_user.present?

          raise
        end

        def link_admin_user_to_vendor!(vendor:, admin_user:, legacy_user: nil)
          return unless defined?(Spree::VendorUser)
          return unless ActiveRecord::Base.connection.data_source_exists?('spree_vendor_users')

          vendor_user = if legacy_user.present?
            Spree::VendorUser.find_by(vendor_id: vendor.id, user_id: legacy_user.id)
          end

          if vendor_user.nil? && Spree::VendorUser.column_names.include?('admin_user_id')
            vendor_user = Spree::VendorUser.find_by(vendor_id: vendor.id, admin_user_id: admin_user.id)
          end

          vendor_user ||= Spree::VendorUser.find_by(vendor_id: vendor.id, admin_user_id: nil)

          vendor_user ||= Spree::VendorUser.new(vendor_id: vendor.id)
          vendor_user.admin_user_id = admin_user.id if vendor_user.respond_to?(:admin_user_id=)
          vendor_user.save! if vendor_user.new_record? || vendor_user.changed?
        end

        def resolve_admin_user_for_vendor(vendor:, email:, password:, legacy_user: nil)
          vendor_user = existing_admin_vendor_link(vendor)
          if vendor_user.present? && vendor_user.admin_user_id.present?
            admin_user = Spree.admin_user_class.find_by(id: vendor_user.admin_user_id)
            return [admin_user, false] if admin_user.present?
          end

          find_or_create_admin_user(email, password, legacy_user: legacy_user)
        end

        def existing_admin_vendor_link(vendor)
          return nil unless defined?(Spree::VendorUser)
          return nil unless ActiveRecord::Base.connection.data_source_exists?('spree_vendor_users')

          Spree::VendorUser.where(vendor_id: vendor.id).where.not(admin_user_id: nil).first ||
            Spree::VendorUser.find_by(vendor_id: vendor.id, admin_user_id: nil)
        end

        def activate_vendor(vendor)
          return if %w[active approved].include?(vendor.state)

          vendor.start_onboarding! if vendor.respond_to?(:start_onboarding!) && vendor.state == 'invited'
          vendor.approve! if vendor.respond_to?(:approve!) && !%w[active approved].include?(vendor.state)
        end

        def existing_vendor(email)
          ::Spree::Vendor.unscoped.find_by(notification_email: email) || ::Spree::Vendor.unscoped.find_by(name: email)
        end

        def existing_admin_user(email)
          Spree.admin_user_class.unscoped.find_by(email: email)
        end

        def existing_legacy_user(email)
          return nil if Spree.user_class == Spree.admin_user_class

          Spree.user_class.unscoped.find_by(email: email)
        end

        def extract_record_not_unique_message(error)
          raw_message = error.cause&.message.presence || error.message
          raw_message.to_s.sub(/\AMysql2::Error:\s*/i, '')
        end

        def revive_vendor!(vendor)
          return if vendor.blank? || vendor.deleted_at.blank?

          vendor.update_columns(deleted_at: nil, updated_at: Time.current)
        end

        def revive_admin_user!(admin_user)
          return if admin_user.blank? || !admin_user.respond_to?(:deleted_at) || admin_user.deleted_at.blank?

          admin_user.update!(deleted_at: nil, updated_at: Time.current)
        end
      end
    end
  end
end