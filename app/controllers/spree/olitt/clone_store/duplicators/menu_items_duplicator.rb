module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class MenuItemsDuplicator < BaseDuplicator
          def initialize(old_store:, new_store:, vendor:, new_menus_cache:, root_menu_items:, linked_resource:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor

            @new_menus_by_location_locale = new_menus_cache
            @old_to_new_menu_item_map = root_menu_items
            @linked_resource = linked_resource

            @depth = 1

            @old_menu_items_by_depth = @old_store.menu_items.includes(%i[parent menu]).group_by(&:depth)
          end

          def handle_clone_menu_items
            while @old_menu_items_by_depth[@depth] && !errors_are_present?
              old_menu_items = @old_menu_items_by_depth[@depth]
              old_menu_items.each do |old_menu_item|
                save_menu_item(old_menu_item: old_menu_item)
                break if errors_are_present?
              end
              @depth += 1
            end
          end

          def save_menu_item(old_menu_item:)
            new_menu_item = old_menu_item.dup
            new_menu_item.parent = @old_to_new_menu_item_map[old_menu_item.parent]
            new_menu_item.menu = get_new_menu(old_menu: old_menu_item.menu)
            new_menu_item.vendor = @vendor
            new_menu_item = @linked_resource.assign_linked_resource(model: new_menu_item) unless new_menu_item.linked_resource_id.nil?
            save_model(model_instance: new_menu_item)
            return if errors_are_present?

            @old_to_new_menu_item_map[old_menu_item] = new_menu_item
          end

          def get_new_menu(old_menu:)
            @new_menus_by_location_locale[old_menu.location][old_menu.locale].first
          end
        end
      end
    end
  end
end
