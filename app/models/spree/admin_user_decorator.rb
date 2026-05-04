module Spree
  module AdminUserDecorator
    def self.prepended(base)
      base.has_many :clone_requests,
                    class_name: 'Spree::Olitt::CloneStore::CloneRequest',
                    foreign_key: :user_id,
                    inverse_of: :admin_user,
                    dependent: :nullify
    end
  end
end

Spree.admin_user_class.prepend(Spree::AdminUserDecorator) unless Spree.admin_user_class < Spree::AdminUserDecorator