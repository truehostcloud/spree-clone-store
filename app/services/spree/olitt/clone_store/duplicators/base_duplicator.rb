module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class BaseDuplicator
          attr_reader :errors

          def initialize
            @errors = []
          end

          def errors_are_present?
            !@errors.empty?
          end

          def save_model(model_instance:, context: nil)
            return true if model_instance.save

            record_errors(model_instance.errors, context: context)
            false
          end

          def assign_vendor(model_instance:, vendor:)
            if model_instance.respond_to?(:vendor=)
              model_instance.vendor = vendor
            elsif model_instance.respond_to?(:vendor_id=)
              model_instance.vendor_id = vendor.id
            end

            model_instance
          end

          def unique_value(base_value:, separator: '-', max_length: nil)
            base_string = base_value.to_s
            candidate = truncate_value(base_string, max_length)
            suffix_index = 2

            while yield(candidate)
              suffix = "#{separator}#{suffix_index}"
              candidate = truncate_value(base_string, max_length, suffix)
              suffix_index += 1
            end

            candidate
          end

          private

          def record_errors(raw_errors, context: nil)
            normalized_errors = normalize_errors(raw_errors)
            message = [context, normalized_errors.join(', ')].compact.join(': ')
            @errors << message
            Rails.logger.error("[spree_clone_store] #{message}")
          end

          def normalize_errors(raw_errors)
            Array(raw_errors).flatten.compact.flat_map do |error|
              next error.full_messages if error.respond_to?(:full_messages)

              error.to_s
            end
          end

          def truncate_value(base_string, max_length, suffix = '')
            return "#{base_string}#{suffix}" if max_length.blank?

            truncated_base = base_string.first(max_length - suffix.length)
            "#{truncated_base}#{suffix}"
          end
        end
      end
    end
  end
end
