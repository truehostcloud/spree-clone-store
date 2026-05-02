module Spree
  module Api
    module V2
      module Platform
        module Ai
          class ThemeVersionsController < BaseController
            def create
              theme_id = params[:theme_theme_id] || params[:theme_id]
              theme = Spree::Theme.find_by(id: theme_id)
              return render_not_found('Theme not found') unless theme

              version = sync_service.snapshot_version(theme, version_params)
              return render_errors(sync_service.errors) if version.nil?

              render json: { data: { id: version['revision'].to_s, type: 'ai_theme_version', attributes: version } }, status: :created
            end

            private

            def sync_service
              @sync_service ||= Spree::Olitt::CloneStore::AiTheme::Sync.new
            end

            def version_params
              params.fetch(:version, params).permit(
                :checksum,
                spec: {}
              ).to_h.symbolize_keys
            end

            def render_errors(errors, status: :unprocessable_entity)
              render json: { errors: normalize_errors(errors) }, status: status
            end

            def render_not_found(message = 'Theme not found')
              render json: { errors: [message] }, status: :not_found
            end
          end
        end
      end
    end
  end
end