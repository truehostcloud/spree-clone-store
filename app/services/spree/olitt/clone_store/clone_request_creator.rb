module Spree
  module Olitt
    module CloneStore
      class CloneRequestCreator
        attr_reader :errors

        def initialize(source_store_id:, store_params:, vendor_params:)
          @source_store_id = source_store_id
          @store_params = store_params.to_h.symbolize_keys
          @vendor_params = vendor_params.to_h.symbolize_keys
          @errors = []
        end

        def call
          validate_vendor_params!

          source_store = resolved_source_store

          CloneRequest.create!(
            source_store: source_store,
            vendor_email: vendor_email,
            vendor_password: vendor_password,
            store_name: @store_params.fetch(:name),
            store_url: @store_params.fetch(:url),
            store_code: @store_params.fetch(:code),
            store_mail_from_address: @store_params.fetch(:mail_from_address)
          )
        rescue ActiveRecord::RecordInvalid => e
          @errors = @errors.presence || e.record.errors.full_messages.presence || [e.message]
          nil
        rescue ActiveRecord::RecordNotUnique => e
          @errors = [extract_record_not_unique_message(e)]
          nil
        rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing => e
          @errors = [e.message]
          nil
        end

        private

        def validate_vendor_params!
          raise ActionController::ParameterMissing, :email if vendor_email.blank?
          raise ActionController::ParameterMissing, :password if vendor_password.blank?

          return if vendor_password_confirmation.blank? || vendor_password == vendor_password_confirmation

          @errors = ["Password confirmation doesn't match Password"]
          raise ActiveRecord::RecordInvalid.new(CloneRequest.new)
        end

        def vendor_email
          @vendor_email ||= @vendor_params.fetch(:email).to_s.strip.downcase
        end

        def vendor_password
          @vendor_params[:password]
        end

        def vendor_password_confirmation
          @vendor_params[:password_confirmation]
        end

        def extract_record_not_unique_message(error)
          raw_message = error.cause&.message.presence || error.message
          raw_message.to_s.sub(/\AMysql2::Error:\s*/i, '')
        end

        def resolved_source_store
          return @source_store if @source_store.present?

          source_store_id = @source_store_id.presence || Spree::Store.default&.id
          Spree::Store.find(source_store_id)
        end
      end
    end
  end
end