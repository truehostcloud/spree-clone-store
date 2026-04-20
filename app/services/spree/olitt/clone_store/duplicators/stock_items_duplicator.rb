module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class StockItemsDuplicator < BaseDuplicator
          DEFAULT_STOCK_COUNT = 5

          def initialize(old_store:, new_store:, vendor:, stock_locations_cache:, variants_cache:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @stock_locations_cache = stock_locations_cache
            @variants_cache = variants_cache
          end

          def handle_clone_stock_items
            source_variants.each do |old_variant|
              clone_variant_stock_items(old_variant)
            rescue StandardError => e
              record_errors([e.message], context: "variant #{old_variant.id}")
            end
          end

          private

          def source_variants
            @old_store.products.includes(variants_including_master: :stock_items).flat_map(&:variants_including_master).uniq(&:id)
          end

          def clone_variant_stock_items(old_variant)
            new_variant = @variants_cache[old_variant.id]&.first
            return if new_variant.blank?

            copied_any_stock_items = false
            old_variant.stock_items.each do |old_stock_item|
              new_stock_location = remapped_stock_location(old_stock_item: old_stock_item)
              next if new_stock_location.blank?

              new_stock_item = new_variant.stock_items.find_or_initialize_by(stock_location: new_stock_location)
              new_stock_item.count_on_hand = old_stock_item.count_on_hand
              new_stock_item.backorderable = old_stock_item.backorderable
              new_stock_item.public_metadata = old_stock_item.public_metadata if new_stock_item.respond_to?(:public_metadata=)
              new_stock_item.private_metadata = old_stock_item.private_metadata if new_stock_item.respond_to?(:private_metadata=)
              new_stock_item.external_id = old_stock_item.external_id if new_stock_item.respond_to?(:external_id=)
              new_stock_item.deleted_at = nil if new_stock_item.respond_to?(:deleted_at=)
              copied_any_stock_items = true if save_model(model_instance: new_stock_item, context: "stock item #{old_stock_item.id}")
            end

            ensure_default_stock_item(old_variant: old_variant, new_variant: new_variant) unless copied_any_stock_items || variant_has_stock_items?(new_variant)
          end

          def remapped_stock_location(old_stock_item:)
            @stock_locations_cache[old_stock_item.stock_location_id]&.first || default_stock_location
          end

          def ensure_default_stock_item(old_variant:, new_variant:)
            new_stock_location = default_stock_location
            return if new_stock_location.blank?

            new_stock_item = new_variant.stock_items.find_or_initialize_by(stock_location: new_stock_location)
            new_stock_item.count_on_hand = fallback_count_on_hand(old_variant: old_variant)
            new_stock_item.backorderable = fallback_backorderable(old_variant: old_variant)
            new_stock_item.deleted_at = nil if new_stock_item.respond_to?(:deleted_at=)
            save_model(model_instance: new_stock_item, context: "default stock item for variant #{old_variant.id}")
          end

          def variant_has_stock_items?(new_variant)
            stock_items = new_variant.stock_items
            return stock_items.exists? if stock_items.respond_to?(:exists?)

            stock_items.any?
          end

          def default_stock_location
            return @default_stock_location if defined?(@default_stock_location)

            @default_stock_location = @stock_locations_cache[:default]&.first ||
                                      @vendor.stock_locations.order(default: :desc, id: :asc).first ||
                                      @stock_locations_cache.values.flatten.compact.first
          end

          def fallback_count_on_hand(old_variant:)
            source_stock_item = old_variant.stock_items.first
            source_stock_item&.count_on_hand.presence || ENV.fetch('CLONE_DEFAULT_STOCK_COUNT', DEFAULT_STOCK_COUNT).to_i
          end

          def fallback_backorderable(old_variant:)
            old_variant.stock_items.any?(&:backorderable)
          end
        end
      end
    end
  end
end