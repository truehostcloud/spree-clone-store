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

          def save_model(model:)
            @errors << model.errors unless model.save
            model
          end
        end
      end
    end
  end
end
