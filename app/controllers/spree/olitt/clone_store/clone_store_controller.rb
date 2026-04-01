require 'json'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        attr_reader :old_store, :new_store

        def clone_store
          created = false

          ActiveRecord::Base.transaction do
            created = handle_clone_store
            raise ActiveRecord::Rollback unless created
          end

          return unless created

          job = enqueue_clone_job
          return if job.nil?

          render_clone_accepted(job)
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

        def render_clone_accepted(job)
          payload = serialize_store(@new_store)
          payload = { data: payload } unless payload.is_a?(Hash)
          payload[:job_id] = job.job_id
          payload[:status] = 'queued'
          payload[:meta] = payload.fetch(:meta, {}).merge(
            clone_status: 'queued',
            status: 'queued',
            job_id: job.job_id,
            clone_job_id: job.job_id,
            source_store_id: @old_store.id,
            cloned_store_id: @new_store.id
          )

          render json: payload, status: :accepted
        end

        def render_clone_job_status(job_id)
          job = find_clone_job(job_id)
          return render_clone_job_not_found(job_id) if job.nil?

          store = store_from_clone_job(job)
          status = clone_job_status(job)
          payload = store.present? ? serialize_store(store) : { data: nil }
          payload = { data: payload } unless payload.is_a?(Hash)
          payload[:job_id] = job.active_job_id
          payload[:status] = status
          payload[:meta] = payload.fetch(:meta, {}).merge(clone_job_status_metadata(job, store))

          render json: payload, status: :ok
        end

        private

        def enqueue_clone_job
          Spree::Olitt::CloneStore::CloneStoreJob.perform_later(
            old_store_id: @old_store.id,
            new_store_id: @new_store.id,
            vendor_id: @vendor.id
          )
        rescue StandardError => e
          cleanup_new_store_after_enqueue_failure
          render json: { errors: ["Unable to queue store clone: #{e.message}"] }, status: :internal_server_error
          nil
        end

        def cleanup_new_store_after_enqueue_failure
          return if @new_store.blank? || @new_store.destroyed?

          @new_store.destroy
        end

        def render_clone_job_not_found(job_id)
          render json: {
            errors: ["Clone job not found for id #{job_id}"],
            meta: {
              job_id: job_id,
              status: 'not_found'
            }
          }, status: :not_found
        end

        def find_clone_job(job_id)
          return nil if job_id.blank?
          return nil unless defined?(SolidQueue::Job)

          job = SolidQueue::Job.find_by(active_job_id: job_id)
          return nil unless clone_store_job?(job)

          job
        end

        def clone_store_job?(job)
          return false if job.nil?

          job_arguments = job.arguments.is_a?(Hash) ? job.arguments : {}
          job_arguments['job_class'] == 'Spree::Olitt::CloneStore::CloneStoreJob'
        end

        def clone_job_arguments(job)
          raw_arguments = job.arguments.is_a?(Hash) ? job.arguments.fetch('arguments', []) : []
          argument_hash = raw_arguments.first
          argument_hash.is_a?(Hash) ? argument_hash : {}
        end

        def store_from_clone_job(job)
          job_args = clone_job_arguments(job)
          store_id = job_args['new_store_id'] || job_args[:new_store_id]
          return nil if store_id.blank?

          Spree::Store.find_by(id: store_id)
        end

        def clone_job_status_metadata(job, store)
          job_args = clone_job_arguments(job)
          {
            job_id: job.active_job_id,
            clone_job_id: job.active_job_id,
            status: clone_job_status(job),
            source_store_id: job_args['old_store_id'] || job_args[:old_store_id],
            cloned_store_id: store&.id || job_args['new_store_id'] || job_args[:new_store_id],
            queue_name: job.queue_name,
            queued_at: job.created_at,
            started_at: job.claimed_execution&.created_at,
            finished_at: job.finished_at,
            error: clone_job_error(job)
          }.compact
        end

        def clone_job_status(job)
          return 'failed' if job.failed_execution.present?
          return 'completed' if job.finished?
          return 'running' if job.claimed_execution.present?

          'queued'
        end

        def clone_job_error(job)
          job.failed_execution&.error
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
