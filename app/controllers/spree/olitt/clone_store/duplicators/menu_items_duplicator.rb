module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class MenuItemsDuplicator < BaseDuplicator
          attr_reader :counter

          def initialize(old_store:, new_store:, new_menus_cache:, root_menu_items:)
            super()
            @old_store = old_store
            @new_store = new_store

            @new_menus_by_location_locale = new_menus_cache
            @old_to_new_menu_item_map = root_menu_items

            @counter = 0
            @depth = 0

            @old_menu_items_by_depth_parent = @old_store.menu_items
                                                        .includes(%i[parent menu]).group_by(&:depth)
                                                        .transform_values { |items| items.group_by(&:parent) }

            @linked_resource = LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)
          end

          def handle_clone_menu_items
            clone_child_menu_item
          end

          def clone_child_menu_item
            while @old_menu_items_by_depth_parent[@depth] and !errors_are_present?
              @counter += 1
              old_menu_items_by_parent = @old_menu_items_by_depth_parent[@depth]
              old_menu_items_by_parent.each do |old_parent, old_menu_items|
                old_menu_items.each do |old_menu_item|
                  new_menu_item = old_menu_item.dup
                  new_menu_item.parent = @old_to_new_menu_item_map[old_parent]
                  new_menu_item.menu = get_new_menu(old_menu: old_menu_item.menu)
                  @old_to_new_menu_item_map[old_menu_item] = new_menu_item
                  save_model(model: new_menu_item)
                end
              end
              @depth += 1
            end
            @old_to_new_menu_item_map
          end

          def get_new_menu(old_menu:)
            @new_menus_by_location_locale[old_menu.location][old_menu.locale].first
          end
        end
      end
    end
  end
end
