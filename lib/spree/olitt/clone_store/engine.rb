module Spree
  module Olitt
    module CloneStore
      class Engine < Rails::Engine
        require 'spree/core'
        isolate_namespace Spree
        engine_name 'spree_clone_store'

        # use rspec for tests
        config.generators do |g|
          g.test_framework :rspec
        end

        initializer 'spree_clone_store.environment', before: :load_config_initializers do |_app|
          Olitt::CloneStore::Config = Olitt::CloneStore::Configuration.new
        end

        def self.activate
          Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
            Rails.configuration.cache_classes ? require(c) : load(c)
          end
        end

        config.to_prepare(&method(:activate).to_proc)
      end
    end
  end
end
