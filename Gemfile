source 'https://rubygems.org'

gem 'spree', github: 'spree/spree', branch: 'main'

group :test do
  gem 'rails-controller-testing'
end

group :development do
  gem 'rcodetools', require: false
  gem 'reek', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'solargraph', require: false
  gem 'spree_sample', github: 'spree/spree', glob: 'sample/*.gemspec', branch: 'main', require: false
end

gemspec
