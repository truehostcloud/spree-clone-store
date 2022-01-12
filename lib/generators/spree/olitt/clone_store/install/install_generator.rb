module Spree
  module Olitt
    module CloneStore
      module Generators
        class InstallGenerator < Rails::Generators::Base
          class_option :migrate, type: :boolean, default: true

          def add_migrations
            run 'bundle exec rake railties:install:migrations FROM=spree_olitt'
          end

          def run_migrations
            run_migrations = options[:migrate] || ['', 'y', 'Y'].include?(ask('Would you like to run the migrations now? [Y/n]'))
            if run_migrations
              run 'bundle exec rails db:migrate'
            else
              Rails.logger.info('Skipping rails db:migrate, don\'t forget to run it!')
            end
          end
        end
      end
    end
  end
end
