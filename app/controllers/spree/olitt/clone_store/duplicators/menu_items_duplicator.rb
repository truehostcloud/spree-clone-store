module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class MenuItemsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store

            @old_menu_items_by_parent = @old_store.menu_items.includes(:menu, :parent).group_by(&:parent)
            @old_menus_by_location_locale = @old_store.menus.group_by(&:location).transform_values { |menus| menus.group_by(&:locale) }

            @new_menu_items_cache = @new_store.menu_items.group_by(&:parent)
            @old_to_new_map = {}

            @linked_resource = LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)

            @errors = []
          end

          def handle_clone_menu_items
            clone_child_menu_item(parent_menu_item: nil)
          end

          def clone_child_menu_item(parent_menu_item:)
            return if are_errors_present?

            return unless @old_menu_items_by_parent.key?(parent_menu_item)

            old_child_menu_items = get_old_menu_items(parent_menu_item: parent_menu_item)

            if parent_menu_item.nil?
              @old_menu_items_by_parent[nil].each do |items|
              end
              return loop_back(old_child_menu_items: old_child_menu_items)
            end

            new_child_menu_items = reassign_menu_items_properies(old_child_menu_items: old_child_menu_items)

            save_new_menu_items(new_child_menu_items: new_child_menu_items)
          end

          def are_errors_present?
            !@errors.empty?
          end

          def loop_back(old_child_menu_items:)
            old_child_menu_items.each { |menu_item| clone_child_menu_item(parent_menu_item: menu_item) }
          end

          def reassign_menu_items_properies(old_child_menu_items:)
            old_child_menu_items.map(&:dup).map do |old_menu_item|
              new_menu = get_new_menu(old_menu: old_menu_item.menu)
              new_parent = get_new_parent(new_menu: new_menum, old_menu_item: old_menu_item)
              old_menu_item.parent = new_parent
              old_menu_item.menu = new_menu
            end
          end

          def get_new_parent(old_menu_item:)
            old_parent = old_menu_item.parent
            new_parent = @old_to_new_map[old_parent]
            return new_parent unless new_parent.nil?

            while new_parent.nil?
              old_parent = old_parent.parent
              new_parent = @old_to_new_map[old_parent]
            end

            new_parent
          end

          def get_new_menu(old_menu:)
            @old_menus_by_location_locale[old_menu.location][old_menu.locale].first
          end

          def save_new_menu_items(new_child_menu_items:)
            new_child_menu_items.each do |menu_item|
              unless menu_item.save
                @errors << menu_item.errors
                break
              end
              # @new_taxons_cache[menu_item.permalink] = [taxon]
            end
          end

          def get_old_menu_items(parent_menu_item:)
            @old_menu_items_by_parent[parent_menu_item]
          end
        end
      end
    end
  end
end
