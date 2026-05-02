module Spree
  module Api
    module V2
      module Platform
        module Ai
          class BaseController < Spree::BaseController
            skip_forgery_protection

            rescue_from Doorkeeper::Errors::DoorkeeperError, with: :render_unauthorized
            rescue_from ActiveRecord::RecordNotUnique, with: :render_bad_request_exception
            rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

            before_action :force_json_request_format
            before_action :validate_token_client
            before_action :authorize_ai_theme_request!

            private

            def force_json_request_format
              request.format = :json
            end

            def validate_token_client
              return if doorkeeper_token.nil?

              raise Doorkeeper::Errors::DoorkeeperError if doorkeeper_token.application.nil?
            end

            def render_unauthorized(_exception)
              render_api_error('Unauthorized', :unauthorized)
            end

            def render_api_error(message, status)
              render json: { error: message }, status: status
            end

            def render_bad_request_exception(exception)
              render json: { errors: [exception.cause&.message || exception.message] }, status: :bad_request
            end

            def render_record_invalid(exception)
              render json: { errors: exception.record.errors.full_messages.presence || [exception.message] }, status: :bad_request
            end

            def spree_current_user
              return nil unless doorkeeper_token
              return nil if doorkeeper_token.resource_owner_id.nil?
              return @spree_current_user if defined?(@spree_current_user)

              @spree_current_user ||= doorkeeper_token.resource_owner
            end

            def superuser_with_global_admin_role?(user)
              return false if user.blank?

              user.role_users.joins(:role).exists?(
                spree_roles: { name: Spree::Role::ADMIN_ROLE },
                resource_type: nil,
                resource_id: nil
              )
            end

            def render_forbidden
              render_api_error(I18n.t('spree.forbidden'), :forbidden)
            end

            def normalize_errors(errors)
              Array(errors).flatten.compact.flat_map do |error|
                next error.full_messages if error.respond_to?(:full_messages)

                error.to_s
              end
            end

            def authorize_ai_theme_request!
              scopes = %i[read admin]
              scopes = %i[write admin] unless %w[show].include?(action_name)
              doorkeeper_authorize!(*scopes)

              return if spree_current_user.nil?
              return if superuser_with_global_admin_role?(spree_current_user)

              store = store_for_authorization
              return if store.blank?

              ability = Spree::VendorAbility.new(spree_current_user) rescue nil
              return if ability && (ability.can?(:manage, store) || ability.can?(:admin, store))

              render_forbidden
            end

            def store_for_authorization
              store_id = params[:store_id] || params.dig(:theme, :store_id)
              return Spree::Store.find_by(id: store_id) if store_id.present?

              theme_id = params[:theme_theme_id] || params[:theme_id]
              return theme_store(theme_id) if theme_id.present?

              page_id = params[:page_page_id] || params[:page_id]
              return if page_id.blank?

              page = Spree::Page.find_by(id: page_id)
              return if page.blank?

              theme_store(page.try(:pageable_id)) || page.try(:pageable)
            end

            def theme_store(theme_or_theme_id)
              theme = theme_or_theme_id.is_a?(Spree::Theme) ? theme_or_theme_id : Spree::Theme.find_by(id: theme_or_theme_id)
              theme&.store
            end
          end
        end
      end
    end
  end
end