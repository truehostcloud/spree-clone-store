module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class SectionsDuplicator < BaseDuplicator
          def initialize(old_store:, new_store:, pages_cache:, linked_resource:)
            super()
            @old_store = old_store
            @new_store = new_store

            @pages_cache = pages_cache
            @linked_resource = linked_resource
          end

          def handle_clone_sections
            sections = @old_store.cms_sections.includes(:cms_page)
            sections.each do |section|
              save_section(old_section: section)
              break if errors_are_present?
            end
          end

          def save_section(old_section:)
            new_section = old_section.dup
            new_section.cms_page = @pages_cache[old_section.cms_page.slug].first
            new_section = @linked_resource.assign_linked_resource(model: new_section) unless new_section.linked_resource_id.nil?
            save_model(model: new_section)
          end
        end
      end
    end
  end
end
