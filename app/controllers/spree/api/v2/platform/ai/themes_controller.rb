module Spree
  module Api
    module V2
      module Platform
        module Ai
          class ThemesController < BaseController
            def create
              store = store_from_params
              return render_not_found('Store not found') if store.blank?

              service = Spree::Olitt::CloneStore::AiTheme::Sync.new(store: store)
              theme = service.upsert_theme(theme_params)
              return render_errors(service.errors) if theme.nil?

              render json: service.theme_payload(theme), status: :created
            end

            def show
              theme = find_theme
              return render_not_found unless theme

              render json: sync_service.theme_payload(theme), status: :ok
            end

            def preview
              theme = find_theme
              return render_not_found unless theme

              token = sync_service.preview_theme(theme)
              return render_errors(sync_service.errors) if token.nil?

              render json: sync_service.theme_payload(theme), status: :accepted
            end

            def publish
              theme = find_theme
              return render_not_found unless theme

              published = sync_service.publish_theme(theme)
              return render_errors(sync_service.errors) if published.nil?

              render json: sync_service.theme_payload(published), status: :ok
            end

            private

            def sync_service
              @sync_service ||= Spree::Olitt::CloneStore::AiTheme::Sync.new(store: store_from_params)
            end

            def store_from_params
              @store_from_params ||= Spree::Store.find_by(id: theme_params[:store_id] || params[:store_id])
            end

            def find_theme
              theme_id = params[:theme_theme_id] || params[:theme_id] || theme_params[:theme_theme_id] || theme_params[:theme_id] || theme_params[:id]
              return nil if theme_id.blank?

              Spree::Theme.find_by(id: theme_id)
            end

            def theme_params
              params.fetch(:theme, params).permit(
                :id,
                :theme_id,
                :store_id,
                :name,
                :default,
                :prompt,
                :status,
                :version,
                :checksum,
                spec: {},
                pages: [
                  :id, :type, :kind, :class_name, :name, :title, :slug, :meta_title, :meta_description,
                  :meta_keywords, :visible,
                  { sections: [
                    :id, :type, :kind, :class_name, :name, :position,
                    { content: {}, settings: {}, preferences: {}, blocks: [
                      :id, :type, :kind, :class_name, :name, :position,
                      { content: {}, settings: {}, preferences: {} }
                    ] }
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