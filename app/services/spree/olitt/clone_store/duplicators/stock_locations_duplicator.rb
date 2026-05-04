module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class StockLocationsDuplicator < BaseDuplicator
          DEFAULT_STOCK_LOCATION_NAME = 'US location'.freeze

          attr_reader :cloned_locations, :locations_cache

          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @cloned_locations = []
            @locations_cache = {}
          end

          def handle_clone_stock_locations
            old_locations = source_stock_locations
            return create_fallback_stock_location if old_locations.empty?

            reusable_location = reusable_default_stock_location(old_locations: old_locations)

            old_locations.each_with_index do |old_location, index|
              clone_stock_location(old_location: old_location, target_location: index.zero? ? reusable_location : nil)
            rescue StandardError => e
              record_errors([e.message], context: "stock location #{old_location.id}")
            end
          end

          private

          def source_stock_locations
            locations = source_vendor_stock_locations + source_variant_stock_locations
            locations.compact.uniq(&:id).sort_by { | location| [location.default ? 0 : 1, location.id || 0] }
          end

          def source_vendor_stock_locations
            return [] unless source_vendor.present? && source_vendor.respond_to?(:stock_locations)

            source_vendor.stock_locations.includes(:country, :state).order(default: :desc, id: :asc).to_a
          end

          def source_variant_stock_locations
            @old_store.products
                      .includes(variants_including_master: { stock_items: :stock_location })
                      .flat_map(&:variants_including_master)
                      .flat_map(&:stock_items)
                      .map(&:stock_location)
                      .compact
                      .uniq(&:id)
          end

          def source_vendor
            return @source_vendor if defined?(@source_vendor)

            @source_vendor = @old_store.respond_to?(:vendor) ? @old_store.vendor : nil
          end

          def clone_stock_location(old_location:, target_location: nil)
            new_location = target_location || find_existing_stock_location(old_location: old_location) || Spree::StockLocation.new

            assign_vendor(model_instance: new_location, vendor: @vendor)
            assign_stock_location_attributes(new_location: new_location, old_location: old_location)
            new_location.name = unique_stock_location_name(old_location: old_location, new_location: new_location)
            saved = save_model(model_instance: new_location, context: "stock location #{old_location.id}")
            return unless saved

            @cloned_locations << new_location unless @cloned_locations.include?(new_location)
            @locations_cache[old_location.id] = [new_location]
            @locations_cache[old_location.name] = [new_location]
            @locations_cache[:default] = [new_location] if new_location.default
          end

          def create_fallback_stock_location
            new_location = reusable_default_stock_location(old_locations: []) ||
                           @vendor.stock_locations.find_by(default: true) ||
                           Spree::StockLocation.new

            assign_vendor(model_instance: new_location, vendor: @vendor)
            assign_fallback_stock_location_attributes(new_location: new_location)
            new_location.name = unique_fallback_stock_location_name(new_location: new_location)
            saved = save_model(model_instance: new_location, context: 'fallback stock location')
            return unless saved

            @cloned_locations << new_location unless @cloned_locations.include?(new_location)
            @locations_cache[:default] = [new_location]
            @locations_cache[new_location.name] = [new_location]
          end

          def assign_stock_location_attributes(new_location:, old_location:)
            new_location.admin_name = old_location.admin_name
            new_location.address1 = old_location.address1
            new_location.address2 = old_location.address2
            new_location.city = old_location.city
            new_location.state = old_location.state
            new_location.state_name = old_location.state_name
            new_location.country = old_location.country || @new_store.default_country
            new_location.zipcode = old_location.zipcode
            new_location.phone = old_location.phone
            new_location.active = old_location.active
            new_location.backorderable_default = old_location.backorderable_default
            new_location.propagate_all_variants = old_location.propagate_all_variants
            new_location.company = old_location.company
            new_location.default = old_location.default
            new_location.deleted_at = nil if new_location.respond_to?(:deleted_at=)
          end

          def assign_fallback_stock_location_attributes(new_location:)
            new_location.admin_name = @new_store.name
            new_location.country = fallback_country
            new_location.active = true
            new_location.backorderable_default = false
            new_location.propagate_all_variants = false
            new_location.company = @new_store.name
            new_location.default = true
            new_location.deleted_at = nil if new_location.respond_to?(:deleted_at=)
          end

          def find_existing_stock_location(old_location:)
            @vendor.stock_locations.find_by(name: old_location.name)
          end

          def unique_stock_location_name(old_location:, new_location:)
            base_name = old_location.name.presence || @new_store.name

            unique_value(base_value: base_name) do |candidate|
              @vendor.stock_locations.where.not(id: new_location.id).where(name: candidate).exists?
            end
          end

          def unique_fallback_stock_location_name(new_location:)
            unique_value(base_value: DEFAULT_STOCK_LOCATION_NAME) do |candidate|
              @vendor.stock_locations.where.not(id: new_location.id).where(name: candidate).exists?
            end
          end

          def fallback_country
            @new_store.default_country || Spree::Country.find_by(iso: 'US') || Spree::Country.first
          end

          def reusable_default_stock_location(old_locations:)
            return if old_locations.empty?

            current_locations = @vendor.stock_locations.order(default: :desc, id: :asc).to_a
            return if current_locations.size != 1

            stock_location = current_locations.first
            return unless stock_location.name == @vendor.name
            return if stock_location.stock_items.exists?
            return if old_locations.any? { |old_location| old_location.name == stock_location.name }

            stock_location
          end
        end
      end
    end
  end
end