module Spree
  module Olitt
    module CloneStore
      module CloneStoreHelpers
        def store_params
          params.require(:store).permit(permitted_store_attributes)
        end

        def source_id_param
          params.require(:source_store_id)
        end

        def resource_serializer
          Spree::Api::V2::Platform::StoreSerializer
        end

        def get_model_hash(models)
          models.map(&:dup).map(&:attributes)
        end

        def save_models(models)
          models.each do |model|
            unless model.save
              render_error_payload(model.errors)
              return false
            end
          end
          true
        end
      end
    end
  end
end
