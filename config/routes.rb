Rails.application.routes.draw do
  root to: 'posts#index'
  resources :posts
  post '/callback' => 'linebot#callback'
end
