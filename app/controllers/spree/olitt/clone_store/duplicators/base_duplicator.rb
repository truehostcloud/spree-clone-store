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

          def save_model(model_instance:)
            @errors << model_instance.errors unless model_instance.save
            model_instance
          end
        end
      end
    end
  end
end
