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
            unless model_instance.save
              model_instance_errors = model_instance.errors
              model_name = model_instance.class.name.demodulize.underscore
              model_instance_errors["model_name"] = model_name
              @errors << model_instance_errors
            end
            model_instance
          end
        end
      end
    end
  end
end
