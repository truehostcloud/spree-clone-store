Spree::Core::Engine.add_routes do
  post '/admin/clone_store', controller: 'olitt/clone_store/clone_store', action: 'clone'

  if Rails.env.development?
    post '/admin/clone_store/test', controller: 'olitt/clone_store/test', action: 'test'
    delete '/admin/delete/taxonomies', controller: 'olitt/clone_store/delete', action: 'taxonomies'
    delete '/admin/delete/taxons', controller: 'olitt/clone_store/delete', action: 'taxons'
    delete '/admin/delete/products', controller: 'olitt/clone_store/delete', action: 'products'
  end
end
