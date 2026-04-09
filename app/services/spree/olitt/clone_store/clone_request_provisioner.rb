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
            vendor, created_vendor = find_or_create_vendor(@clone_request.vendor_email)
            user, created_user = find_or_create_user(@clone_request.vendor_email, @clone_request.vendor_password)
            role_user, created_role_user = assign_vendor_role(user, vendor)

            activate_vendor(vendor)

            store = @clone_request.store || build_store(source_store: source_store, vendor: vendor)
            store.save! unless store.persisted?

            @clone_request.update!(
              store: store,
              vendor: vendor,
              user: user,
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

        def find_or_create_user(email, password)
          user = existing_user(email) || Spree.user_class.find_or_initialize_by(email: email)
          revive_user!(user) if user.present?
          return [user, false] if user.persisted?

          user.password = password
          user.password_confirmation = password
          user.save!

          [user, true]
        rescue ActiveRecord::RecordNotUnique
          user = existing_user(email)
          revive_user!(user) if user.present?
          return [user, false] if user.present?

          raise
        end

        def assign_vendor_role(user, vendor)
          vendor_role_name = defined?(Spree::Vendor::DEFAULT_VENDOR_ROLE) ? Spree::Vendor::DEFAULT_VENDOR_ROLE : 'vendor'
          vendor_role = Spree::Role.find_or_create_by!(name: vendor_role_name)
          role_user = Spree::RoleUser.find_by(user: user, role: vendor_role, resource: vendor)
          return [role_user, false] if role_user.present?

          [Spree::RoleUser.create!(user: user, role: vendor_role, resource: vendor), true]
        rescue ActiveRecord::RecordNotUnique
          role_user = Spree::RoleUser.find_by(user: user, role: vendor_role, resource: vendor)
          return [role_user, false] if role_user.present?

          raise
        end

        def activate_vendor(vendor)
          return if %w[active approved].include?(vendor.state)

          vendor.start_onboarding! if vendor.respond_to?(:start_onboarding!) && vendor.state == 'invited'
          vendor.approve! if vendor.respond_to?(:approve!) && !%w[active approved].include?(vendor.state)
        end

        def existing_vendor(email)
          ::Spree::Vendor.unscoped.find_by(notification_email: email) || ::Spree::Vendor.unscoped.find_by(name: email)
        end

        def existing_user(email)
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

        def revive_user!(user)
          return if user.blank? || !user.respond_to?(:deleted_at) || user.deleted_at.blank?

          user.update_columns(deleted_at: nil, updated_at: Time.current)
        end
      end
    end
  end
end