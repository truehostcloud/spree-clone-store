require 'json'

module Spree
  module Olitt
    module CloneStore
      class CloneStoreController < Spree::BaseController
        include Spree::Olitt::CloneStore::CloneStoreHelpers

        def clone_store
          clone_request = build_clone_request
          return if clone_request.nil?

          job = enqueue_clone_job(clone_request)
          return if job.nil?

          clone_request.mark_enqueued!(job)
          render json: serialize_clone_request(clone_request), status: :accepted
        end

        def render_clone_job_status(job_id)
          clone_request = CloneRequest.find_by(job_id: job_id)
          return render_clone_job_not_found(job_id) if clone_request.nil?

          render json: serialize_clone_request(clone_request), status: :ok
        end

        private

        def build_clone_request
          source_store_id = source_id_param
          permitted_store_params = store_params
          permitted_vendor_params = vendor_params

          creator = CloneRequestCreator.new(
            source_store_id: source_store_id,
            store_params: permitted_store_params,
            vendor_params: permitted_vendor_params
          )
          clone_request = creator.call
          return clone_request if clone_request.present?

          render_error_payload(creator.errors)
          nil
        rescue ActionController::ParameterMissing => e
          render_error_payload([e.message])
          nil
        end

        def enqueue_clone_job(clone_request)
          Spree::Olitt::CloneStore::CloneStoreJob.perform_later(clone_request.id)
        rescue StandardError => e
          cleanup_failed_clone_request(clone_request)
          render json: { errors: ["Unable to queue store clone: #{e.message}"] }, status: :internal_server_error
          nil
        end

        def cleanup_failed_clone_request(clone_request)
          clone_request.cleanup_failed_clone!
          clone_request.destroy!
        end

        def render_clone_job_not_found(job_id)
          render json: {
            errors: ["Clone job not found for id #{job_id}"],
            meta: {
              job_id: job_id,
              status: 'not_found'
            }
          }, status: :not_found
        end

        def serialize_clone_request(clone_request)
          CloneRequestPresenter.new(clone_request: clone_request, serializer: method(:serialize_store)).as_json
        end

        def render_error_payload(errors)
          render json: { errors: normalize_errors(errors) }, status: :unprocessable_entity
        end

        def normalize_errors(errors)
          Array(errors).flatten.compact.flat_map do |error|
            next error.full_messages if error.respond_to?(:full_messages)

            error.to_s
          end
        end

        def serialize_store(store)
          serializer = resource_serializer.new(store)
          return serializer.serializable_hash if serializer.respond_to?(:serializable_hash)

          serializer
        rescue StandardError
          {
            data: {
              id: store.id.to_s,
              type: 'store',
              attributes: {
                name: store.name,
                url: store.url,
                code: store.code,
                mail_from_address: store.mail_from_address
              }
            }
          }
        end
      end
    end
  end
end
