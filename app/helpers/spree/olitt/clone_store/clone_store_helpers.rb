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

        def required_store_params
          name, url, code, mail_from_address = store_params.values_at(:name, :url, :code, :mail_from_address)

          raise ActionController::ParameterMissing, :name if name.nil?
          raise ActionController::ParameterMissing, :url if url.nil?
          raise ActionController::ParameterMissing, :code if code.nil?
          raise ActionController::ParameterMissing, :mail_from_address if mail_from_address.nil?

          [name, url, code, mail_from_address]
        end
      end
    end
  end
end