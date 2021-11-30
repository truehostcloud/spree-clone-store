module Spree
  module Olitt
    module CloneStore
      module Duplicators
        class BaseDuplicator
          attr_reader :errors

          def initialize
            @errors = []
          end

          def are_errors_present?
            !@errors.empty?
          end

          def save_models(models:)
            models.each do |model|
              break if are_errors_present?

              save_model(model: model)
            end
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
