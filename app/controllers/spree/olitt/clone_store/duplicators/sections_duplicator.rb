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
            sections = @old_store.cms_sections.includes(:cms_page, :image_one, :image_two, :image_three)
            sections.each do |section|
              save_section(old_section: section)
              break if errors_are_present?
            end
          end

          def save_section(old_section:)
            new_section = old_section.dup
            new_section.cms_page = @pages_cache[old_section.cms_page.slug].first
            new_section = duplicate_images(new_section: new_section, old_section: old_section)
            new_section = @linked_resource.assign_linked_resource(model: new_section) unless new_section.linked_resource_id.nil?
            save_model(model_instance: new_section)
          end

          def duplicate_images(new_section:, old_section:)
            new_section.image_one.attach(old_section.image_one.blob) unless old_section.image_one.nil?
            new_section.image_two.attach(old_section.image_two.blob) unless old_section.image_two.nil?
            new_section.image_three.attach(old_section.image_three.blob) unless old_section.image_three.nil?
            new_section
          end
        end
      end
    end
  end
end
