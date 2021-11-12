Spree::Core::Engine.add_routes do
  post '/admin/clone_store', controller: 'olitt/clone_store/clone_store', action: 'test'
end
