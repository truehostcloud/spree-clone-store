module Spree
  module Api
    module V2
      module Platform
        module Ai
          class ThemePagesController < BaseController
            def create
              theme_id = params[:theme_theme_id] || params[:theme_id]
              theme = Spree::Theme.find_by(id: theme_id)
              return render_not_found('Theme not found') unless theme

              page = sync_service.upsert_page(theme, page_params)
              return render_errors(sync_service.errors) if page.nil?

              render json: sync_service.page_payload(page), status: :created
            end

            private

            def sync_service
              @sync_service ||= Spree::Olitt::CloneStore::AiTheme::Sync.new
            end

            def page_params
              params.fetch(:page, params).permit(
                :id,
                :theme_id,
                :type,
                :kind,
                :class_name,
                :name,
                :title,
                :slug,
                :meta_title,
                :meta_description,
                :meta_keywords,
                :visible,
                :prompt,
                :status,
                :version,
                spec: {},
                sections: [
                  :id, :type, :kind, :class_name, :name, :position,
                  { content: {}, settings: {}, preferences: {}, blocks: [
                    :id, :type, :kind, :class_name, :name, :position,
                    { content: {}, settings: {}, preferences: {} }
                  ] }
                ]
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