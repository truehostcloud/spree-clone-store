module Spree
  module Olitt
    module CloneStore
      module CloneStoreHelpers
        def clone_store_payload
          raw_payload = params[:clone_store]
          return params if raw_payload.blank?

          raw_payload.respond_to?(:permit) ? raw_payload : ActionController::Parameters.new(raw_payload)
        end

        def store_params
          clone_store_payload.require(:store).permit(:name, :url, :code, :mail_from_address)
        end

        def vendor_params
          clone_store_payload.require(:vendor).permit([:email, :password, :password_confirmation])
        end

        def source_id_param
          clone_store_payload.require(:source_store_id)
        end

        def resource_serializer
          Spree::Api::V2::Platform::StoreSerializer
        rescue NameError
          Spree::V2::Platform::StoreSerializer
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
