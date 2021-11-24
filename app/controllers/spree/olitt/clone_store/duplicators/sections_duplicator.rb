module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class SectionsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = Spree::Store.includes(:taxonomies).find_by(id: new_store.id)
            @linked_resource = LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)
          end

          def handle_clone_sections
            old_sections = @old_store.cms_sections
            new_sections = old_sections.map { |section| add_new_page_to_section(old_section: section) }
            new_sections = new_sections.map { |section| add_linked_resource_to_section(old_section: section) }
            return false unless save_models(new_sections)

            true
          end

          def add_new_page_to_section(old_section:)
            new_page = @new_store.cms_pages.find_by(slug: old_section.cms_page.slug)
            new_section = old_section.dup
            new_section.cms_page = new_page
            new_section
          end

          def add_linked_resource_to_section(old_section:)
            return old_section unless old_section.methods.include? :linked_resource_type
            return old_section if old_section.linked_resource_type.nil?

            new_resource_id = get_new_section_linked_resource(resource_id: old_section.linked_resource_id,
                                                              resource_type: old_section.linked_resource_type)

            return reset_section_resource(section: old_section) if new_resource_id.nil?

            old_section.linked_resource_id = new_resource_id
            old_section
          end

          def get_new_section_linked_resource(resource_id:, resource_type:)
            resource = resource_type.constantize
            old_linked_resource = resource.find_by(id: resource_id)

            if old_linked_resource.instance_of?('Spree::Taxon'.constantize)
              return @linked_resource.get_new_linked_taxon(old_taxon: old_linked_resource)
            end

            if old_linked_resource.instance_of?('Spree::Product'.constantize)
              return @linked_resource.get_new_linked_product(old_product: old_linked_resource)
            end

            nil
          end

          def reset_section_resource(section:)
            section.linked_resource_id = nil
            section.linked_resource_type = nil
            section
          end
        end
      end
    end
  end
end
