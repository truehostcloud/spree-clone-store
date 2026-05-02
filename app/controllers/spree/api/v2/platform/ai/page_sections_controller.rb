module Spree
  module Api
    module V2
      module Platform
        module Ai
          class PageSectionsController < BaseController
            def create
              page_id = params[:page_page_id] || params[:page_id]
              page = Spree::Page.find_by(id: page_id)
              return render_not_found('Page not found') unless page

              section = sync_service.upsert_section(page, section_params)
              return render_errors(sync_service.errors) if section.nil?

              render json: sync_service.section_payload(section), status: :created
            end

            private

            def sync_service
              @sync_service ||= Spree::Olitt::CloneStore::AiTheme::Sync.new
            end

            def section_params
              params.fetch(:section, params).permit(
                :id,
                :type,
                :kind,
                :class_name,
                :name,
                :position,
                :prompt,
                :status,
                :version,
                content: {},
                settings: {},
                preferences: {},
                blocks: [
                  :id, :type, :kind, :class_name, :name, :position,
                  { content: {}, settings: {}, preferences: {} }
                ]
              ).to_h.symbolize_keys
            end

            def render_errors(errors, status: :unprocessable_entity)
              render json: { errors: normalize_errors(errors) }, status: status
            end

            def render_not_found(message = 'Page not found')
              render json: { errors: [message] }, status: :not_found
            end
          end
        end
      end
    end
  end
end