lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree/olitt/clone_store/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_clone_store'
  s.version     = Spree::Olitt::CloneStore::VERSION
  s.summary     = 'Clones a store for a customer'
  s.description = s.summary
  s.required_ruby_version = '>= 2.5'

  s.author    = ['Collins Lagat & Steve G', 'Ryanada Ltd']
  s.email     = ['info@olitt.com']
  s.homepage  = 'https://github.com/truehostcloud/spree-clone-store'
  s.license = 'MIT'

  s.files = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(%r{^spec/fixtures}) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '>= 4.3.0'
  s.add_dependency 'spree_extension'

  s.add_development_dependency 'spree_dev_tools'
end
