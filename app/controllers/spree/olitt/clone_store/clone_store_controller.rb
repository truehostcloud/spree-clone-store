module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::Api::V2::BaseController
        helper Spree::Olitt::CloneStore::TaxonomyHelpers

        def clone
          source_id = source_id_param
          raise ActionController::ParameterMissing if source_id.nil?

          source_store = Spree::Store.find_by(id: source_id)
          raise ActiveRecord::RecordNotFound if source_store.nil?

          @store = update_store_details, source_store.dup

          if @store.save
            render_serialized_payload(201) { serialize_resource(@store) }
          else
            render_error_payload(@store.errors)
          end
        end

        private

        attr_accessor :store

        def update_store_details(store)
          name, url, code, mail_from_address = required_store_params

          store.name = name
          store.url = url
          store.code = code
          store.mail_from_address = mail_from_address
        end

        def required_store_params
          name, url, code, mail_from_address = store_params.values_at(:name, :url, :code, :mail_from_address)

          raise ActionController::ParameterMissing, :name if name.nil?
          raise ActionController::ParameterMissing, :url if url.nil?
          raise ActionController::ParameterMissing, :code if code.nil?
          raise ActionController::ParameterMissing, :mail_from_address if mail_from_address.nil?

          [name, url, code, mail_from_address]
        end

        def store_params
          params.require(:store).permit(permitted_store_attributes)
        end

        def source_id_param
          params.require(:source_store_id)
        end

        def resource_serializer
          Spree::Api::V2::Platform::StoreSerializer
        end
      end
    end
  end
end
