module Spree
  module Olitt
    module CloneStore
      class CloneRequest < ::ApplicationRecord
        self.table_name = 'spree_clone_store_requests'

        enum :status,
             {
               pending: 'pending',
               queued: 'queued',
               running: 'running',
               completed: 'completed',
               failed: 'failed'
             },
             default: :pending,
             validate: true

        belongs_to :source_store, class_name: 'Spree::Store'
        belongs_to :store, class_name: 'Spree::Store', optional: true
        belongs_to :vendor, class_name: 'Spree::Vendor', optional: true
        belongs_to :admin_user, class_name: Spree.admin_user_class.to_s, foreign_key: :user_id, optional: true
        belongs_to :role_user, class_name: 'Spree::RoleUser', optional: true

        validates :store_name, :store_url, :store_code, :store_mail_from_address, :vendor_email, :vendor_password, presence: true

        def user
          admin_user
        end

        def user=(value)
          self.admin_user = value
        end

        def mark_enqueued!(job)
          update!(
            job_id: job.job_id,
            queue_name: job.queue_name,
            enqueued_at: Time.current,
            status: :queued,
            error_message: nil
          )
        end

        def mark_running!
          update!(status: :running, started_at: started_at || Time.current, error_message: nil)
        end

        def mark_completed!
          update!(status: :completed, finished_at: Time.current, error_message: nil)
        end

        def mark_failed!(message)
          update!(status: :failed, error_message: message, finished_at: Time.current)
        end

        def cleanup_failed_clone!
          cloned_store = store
          assigned_role_user = created_role_user? ? role_user : nil
          assigned_admin_user = created_user? ? admin_user : nil
          assigned_vendor = created_vendor? ? vendor : nil

          update_columns(store_id: nil, role_user_id: nil, user_id: nil, vendor_id: nil)

          cloned_store&.destroy!
          assigned_role_user&.destroy!

          if assigned_admin_user.present?
            assigned_admin_user.reload
            assigned_admin_user.destroy! if assigned_admin_user.role_users.reload.none?
          end

          if assigned_vendor.present?
            assigned_vendor.reload
            assigned_vendor.destroy! unless Spree::Store.where(vendor_id: assigned_vendor.id).exists?
          end
        end

        def fallback_store_payload
          {
            data: {
              id: store_id&.to_s,
              type: 'store',
              attributes: {
                name: store_name,
                url: store_url,
                code: store_code,
                mail_from_address: store_mail_from_address
              }
            }
          }
        end
      end
    end
  end
end