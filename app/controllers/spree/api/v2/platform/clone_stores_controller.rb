module Spree
  module Api
    module V2
      module Platform
        class CloneStoresController < Spree::Olitt::CloneStore::CloneStoreController
          skip_forgery_protection

          rescue_from Doorkeeper::Errors::DoorkeeperError, with: :render_unauthorized
          rescue_from ActiveRecord::RecordNotUnique, with: :render_bad_request_exception
          rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

          before_action :force_json_request_format
          before_action :validate_token_client
          before_action :authorize_clone_store_request!
          before_action :authorize_superadmin_user_token!

          def create
            clone_store
          end

          def show
            render_clone_request_status(params[:clone_request_id])
          end

          private

          def authorize_clone_store_request!
            scopes = action_name == 'show' ? %i[read admin] : %i[write admin]
            doorkeeper_authorize!(*scopes)
          end

          def authorize_superadmin_user_token!
            return if spree_current_user.nil?
            return if superuser_with_global_admin_role?(spree_current_user)

            render_api_error(I18n.t('spree.forbidden'), :forbidden)
          end

          def force_json_request_format
            request.format = :json
          end

          def render_unauthorized(_exception)
            render_api_error('Unauthorized', :unauthorized)
          end

          def validate_token_client
            return if doorkeeper_token.nil?

            raise Doorkeeper::Errors::DoorkeeperError if doorkeeper_token.application.nil?
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
            return false unless user.present?

            user.role_users.joins(:role).exists?(
              spree_roles: { name: Spree::Role::ADMIN_ROLE },
              resource_type: nil,
              resource_id: nil
            )
          end
        end
      end
    end
  end
end