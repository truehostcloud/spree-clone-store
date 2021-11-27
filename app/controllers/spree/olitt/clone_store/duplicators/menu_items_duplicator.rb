module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class MenuItemsDuplicator
          include Spree::Olitt::CloneStore::CloneStoreHelpers

          def initialize(old_store:, new_store:)
            @old_store = old_store
            @new_store = new_store

            @old_menu_items_by_parent = @old_store.menu_items.includes(:menu, :parent).group_by(&:parent_id)
            @old_menus_by_location_locale = @old_store.menus.group_by(&:location).transform_values do |menus|
              menus.group_by(&:locale)
            end

            @new_menu_items_cache = @new_store.menu_items
            @linked_resource = LinkedResourceDuplicator.new(old_store: @old_store, new_store: @new_store)

            @errors = []
          end

          def handle_clone_menu_items
            clone_child_menu_item(parent_menu_item_id: nil)
          end

          def clone_child_menu_item(parent_menu_item_id:)
            return if are_errors_present?

            return unless @old_menu_items_by_parent.key?(parent_menu_item_id)

            old_child_menu_items = get_old_menu_items(parent_menu_item_id: parent_menu_item_id)

            return loop_back(old_child_menu_items: old_child_menu_items) if parent_menu_item_id.nil?

            new_child_menu_items = reassign_menu_items_properies(old_child_menu_items: old_child_menu_items)

            save_new_menu_items(new_child_menu_items: new_child_menu_items)
          end

          def are_errors_present?
            !@errors.empty?
          end

          def loop_back(old_child_menu_items:)
            old_child_menu_items.each { |menu_item| clone_child_menu_item(parent_menu_item_id: menu_item.id) }
          end

          def reassign_menu_items_properies(old_child_menu_items:)
            old_child_menu_items.map(&:dup).map do |old_menu_item|
              old_menu_item
              old_menu_item
            end
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

          def get_old_menu_items(parent_menu_item_id:)
            @old_menu_items_by_parent[parent_menu_item_id]
          end
        end
      end
    end
  end
end
