module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class OptionTypesDuplicator < BaseDuplicator
          attr_reader :option_types_cache, :option_values_cache

          def initialize(old_store:, new_store:, vendor:)
            super()
            @old_store = old_store
            @new_store = new_store
            @vendor = vendor
            @option_types_cache = {}
            @option_values_cache = {}
          end

          def handle_clone_option_types
            source_option_types.each do |option_type|
              clone_option_type(option_type)
            rescue StandardError => e
              record_errors([e.message], context: "option type #{option_type.id}")
            end
          end

          private

          def source_option_types
            @source_option_types ||= @old_store.products.includes(option_types: :option_values).flat_map(&:option_types).compact.uniq(&:id)
          end

          def clone_option_type(option_type)
            new_option_type = find_or_initialize_option_type(option_type: option_type)
            assign_vendor(model_instance: new_option_type, vendor: @vendor)
            assign_option_type_attributes(new_option_type: new_option_type, option_type: option_type)
            saved = save_model(model_instance: new_option_type, context: "option type #{option_type.id}")
            return unless saved

            cache_option_type(old_option_type: option_type, new_option_type: new_option_type)
            clone_option_values(old_option_type: option_type, new_option_type: new_option_type)
          end

          def find_or_initialize_option_type(option_type:)
            option_type_for_vendor(option_type: option_type) || Spree::OptionType.new
          end

          def option_type_for_vendor(option_type:)
            return unless option_type.vendor_id == @vendor.id

            Spree::OptionType.find_by(id: option_type.id)
          end

          def assign_option_type_attributes(new_option_type:, option_type:)
            new_option_type.name = unique_option_type_name(option_type: option_type, new_option_type: new_option_type)
            new_option_type.presentation = option_type.presentation
            new_option_type.position = option_type.position
            new_option_type.filterable = option_type.filterable
            new_option_type.public_metadata = option_type.public_metadata if new_option_type.respond_to?(:public_metadata=)
            new_option_type.private_metadata = option_type.private_metadata if new_option_type.respond_to?(:private_metadata=)
          end

          def clone_option_values(old_option_type:, new_option_type:)
            old_option_type.option_values.each do |option_value|
              new_option_value = find_or_initialize_option_value(new_option_type: new_option_type, option_value: option_value)
              assign_vendor(model_instance: new_option_value, vendor: @vendor)
              new_option_value.option_type = new_option_type
              new_option_value.name = option_value.name
              new_option_value.presentation = option_value.presentation
              new_option_value.position = option_value.position
              new_option_value.public_metadata = option_value.public_metadata if new_option_value.respond_to?(:public_metadata=)
              new_option_value.private_metadata = option_value.private_metadata if new_option_value.respond_to?(:private_metadata=)
              saved = save_model(model_instance: new_option_value, context: "option value #{option_value.id}")
              next unless saved

              cache_option_value(old_option_value: option_value, new_option_value: new_option_value)
            rescue StandardError => e
              record_errors([e.message], context: "option value #{option_value.id}")
            end
          end

          def find_or_initialize_option_value(new_option_type:, option_value:)
            new_option_type.option_values.find_by(name: option_value.name) || Spree::OptionValue.new
          end

          def cache_option_type(old_option_type:, new_option_type:)
            @option_types_cache[old_option_type.id] = [new_option_type]
          end

          def cache_option_value(old_option_value:, new_option_value:)
            @option_values_cache[old_option_value.id] = [new_option_value]
          end

          def unique_option_type_name(option_type:, new_option_type:)
            base_name = if option_type.vendor_id == @vendor.id
                          option_type.name
                        else
                          [option_type.name, @new_store.code.presence].compact.join('_')
                        end

            unique_value(base_value: base_name, separator: '_', max_length: 100) do |candidate|
              Spree::OptionType.where.not(id: new_option_type.id).where(name: candidate).exists?
            end
          end
        end
      end
    end
  end
end