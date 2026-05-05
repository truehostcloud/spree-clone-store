require 'json'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        attr_reader :old_store, :new_store

        def clone_store
          clone_request = create_clone_request
          return if clone_request.nil?

          clone_request = enqueue_clone_job(clone_request)
          return if clone_request.nil?

          render_clone_accepted(clone_request)
        end

        def render_error(duplicator:)
          render_error_payload(duplicator.errors)
          raise ActiveRecord::Rollback
        end

        def handle_create_vendor(email, password, password_confirmation)
          user_email = email.to_s.strip.downcase
          @vendor = find_or_create_vendor(user_email)
          legacy_user = existing_legacy_user(user_email)
          admin_user, = resolve_admin_user_for_vendor(
            vendor: @vendor,
            email: user_email,
            password: password,
            password_confirmation: password_confirmation,
            legacy_user: legacy_user
          )
          assign_vendor_role(admin_user, @vendor)
          link_admin_user_to_vendor!(vendor: @vendor, admin_user: admin_user, legacy_user: legacy_user)
          activate_vendor(@vendor)
        end

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

          store = clone_and_update_store(@old_store.dup)

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

        def finish
          @new_store.reload
          render json: serialize_store(@new_store), status: :created
        end

        def render_clone_accepted(clone_request)
          render json: serialize_clone_request(clone_request), status: :accepted
        end

        def render_clone_request_status(clone_request_id)
          clone_request = find_clone_request(clone_request_id)
          return render_clone_request_not_found(clone_request_id) if clone_request.nil?

          render json: serialize_clone_request(clone_request), status: :ok
        end

        private

        def enqueue_clone_job(clone_request)
          job = Spree::Olitt::CloneStore::CloneStoreJob.perform_later(clone_request.id)
          clone_request.mark_enqueued!(job)
          clone_request.reload
        rescue StandardError => e
          cleanup_new_store_after_enqueue_failure(clone_request)
          render json: { errors: ["Unable to queue store clone: #{e.message}"] }, status: :internal_server_error
          nil
        end

        def cleanup_new_store_after_enqueue_failure(clone_request)
          return if clone_request.blank?

          clone_request.mark_failed!('Failed to enqueue clone job')
          clone_request.cleanup_failed_clone!
        end

        def render_clone_request_not_found(clone_request_id)
          render json: {
            errors: ["Clone request not found for id #{clone_request_id}"],
            meta: {
              clone_request_id: clone_request_id,
              status: 'not_found'
            }
          }, status: :not_found
        end

        def find_clone_request(clone_request_id)
          return nil if clone_request_id.blank?

          CloneRequest.find_by(id: clone_request_id)
        end

        def create_clone_request
          creator = CloneRequestCreator.new(
            source_store_id: source_id_param,
            store_params: store_params,
            vendor_params: vendor_params
          )
          clone_request = creator.call

          if clone_request.present?
            @old_store = clone_request.source_store
            @new_store = clone_request.store
          else
            render_error_payload(creator.errors, status: :bad_request)
            return nil
          end

          clone_request
        rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing => e
          render_error_payload([e.message], status: :bad_request)
          nil
        end

        def serialize_clone_request(clone_request)
          CloneRequestPresenter.new(
            clone_request: clone_request,
            serializer: method(:serialize_store)
          ).as_json
        end

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

        def find_or_create_admin_user(email, password, password_confirmation, legacy_user: nil)
          admin_user = Spree.admin_user_class.find_or_initialize_by(email: email)
          return admin_user if admin_user.persisted?

          admin_user.login ||= email if admin_user.respond_to?(:login=)
          admin_user.password = password
          admin_user.password_confirmation = password_confirmation.presence || password if admin_user.respond_to?(:password_confirmation=)

          if legacy_user.present?
            admin_user.first_name ||= legacy_user.first_name if admin_user.respond_to?(:first_name=)
            admin_user.last_name ||= legacy_user.last_name if admin_user.respond_to?(:last_name=)
            admin_user.selected_locale ||= legacy_user.selected_locale if admin_user.respond_to?(:selected_locale=)
          end

          admin_user.save!
          admin_user
        end

        def assign_vendor_role(admin_user, vendor)
          vendor_role_name = defined?(Spree::Vendor::DEFAULT_VENDOR_ROLE) ? Spree::Vendor::DEFAULT_VENDOR_ROLE : 'vendor'
          vendor_role = vendor.respond_to?(:default_user_role) ? (vendor.default_user_role || Spree::Role.find_or_create_by!(name: vendor_role_name)) : Spree::Role.find_or_create_by!(name: vendor_role_name)

          Spree::RoleUser.find_or_create_by!(
            user: admin_user,
            role: vendor_role,
            resource: vendor
          )
        end

        def existing_legacy_user(email)
          return nil if Spree.user_class == Spree.admin_user_class

          Spree.user_class.find_by(email: email)
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

        def resolve_admin_user_for_vendor(vendor:, email:, password:, password_confirmation:, legacy_user: nil)
          vendor_user = existing_admin_vendor_link(vendor)
          if vendor_user.present? && vendor_user.admin_user_id.present?
            admin_user = Spree.admin_user_class.find_by(id: vendor_user.admin_user_id)
            return [admin_user, false] if admin_user.present?
          end

          find_or_create_admin_user(email, password, password_confirmation, legacy_user: legacy_user)
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

        def render_error_payload(errors, status: :unprocessable_entity)
          render json: { errors: normalize_errors(errors) }, status: status
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
