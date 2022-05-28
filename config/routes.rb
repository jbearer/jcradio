Rails.application.routes.draw do
  resources :notifications, only: [:index, :destroy, :show]
  resources :users, only: [:index, :show, :new, :create, :destroy]
  resources :sessions, only: [:index, :create]
  delete "/sessions", to: 'sessions#destroy'  # API
  post "/logout", to: "sessions#destroy"      # Forms
  get "/sessions/subscribe", to: "sessions#subscribe"
  if Rails.env.development?
    post "/sessions/notifyme", to: "sessions#test_notifications"
  end

  resources :songs, only: [:index]
  get "/songs/search", to: "songs#search"
  get "/songs/inline_search", to: "songs#inline_search"
  get "/songs/browse", to: "songs#browse"

  resources :stations, only: [:index, :show]
  post "/stations/:id", to: 'stations#update'
  post "/stations/:id/save", to: "stations#save"
  post "/stations/:id/refresh", to: "stations#refresh"

  resources :chat, only: [:index, :create, :show]
  resources :emojis, only: [:index, :new, :create, :show]
  resources :upvotes, only: [:create]

  get '/auth/spotify/callback', to: 'stations#spotify_create_user'

  root 'sessions#index'

  get 'sessions/test_webrtc'

  post '/sessions/radio_spotify_logout', to: "sessions#radio_spotify_logout"
  post '/stations/:id/user_spotify_logout', to: "stations#user_spotify_logout"
  post '/stations/:id/user_spotify_reload_library', to: "stations#user_spotify_reload_library"

  post '/sessions/librespot_start', to: "sessions#librespot_start"

  get '/stations/:id/change_queue_pos', to: "stations#change_queue_pos"
  post '/stations/:id/edit_queue_pos',  to: "stations#edit_queue_pos"

  post '/stations/:id/skip_song',  to: "stations#skip_song"

  resources :recommendations, only: [:index, :create]

  get "/recommendations/search", to: "recommendations#search"
  get "/recommendations/suggest", to: "recommendations#suggest"
  post "/recommendations/add_seed", to: "recommendations#add_seed"

  # Buddy
  resources :buddy, only: [:index, :create, :show]

  post "/buddy/configure", to: "buddy#configure"


  get "/stations/:id/plots", to: "stations#plots"

  get "/songs/birth", to: "songs#birth"



  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
