module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class PagesDuplicator < BaseDuplicator
          attr_reader :pages_cache

          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store

            @pages_cache = {}
            @vendor = vendor
          end

          def handle_clone_pages
            return unless @old_store.respond_to?(:cms_pages)

            pages = @old_store.cms_pages
            pages.each do |old_page|
              new_page = old_page.dup
              new_page.store = @new_store
              assign_vendor(model_instance: new_page, vendor: @vendor)
              new_page.slug = unique_page_slug(old_page: old_page)
              saved = save_model(model_instance: new_page, context: "page #{old_page.id}")
              next unless saved

              @pages_cache[old_page.slug] = [new_page]
            rescue StandardError => e
              record_errors([e.message], context: "page #{old_page.id}")
            end
          end

          private

          def unique_page_slug(old_page:)
            base_slug = old_page.slug.presence || old_page.name.to_s.parameterize
            unique_value(base_value: base_slug, max_length: 255) do |candidate|
              @new_store.cms_pages.where(slug: candidate).exists?
            end
          end
        end
      end
    end
  end
end
