module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class StockItemsDuplicator < BaseDuplicator
          def initialize(old_store:, new_store:, vendor:, products_cache:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @products_cache = products_cache
          end

          def handle_clone_stock_items
            @old_store.products.each do |old_product|
              new_product = @products_cache[old_product.slug].first
              new_product.variants.each do |new_variant|
                @vendor.stock_locations.each do |new_stock_location|
                  new_stock_item = new_stock_location.stock_item_or_create(new_variant)
                  new_stock_item.update(count_on_hand: old_product.total_on_hand)
                end
              end
            end
          end
        end
      end
    end
  end
end
