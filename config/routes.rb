Rails.application.routes.draw do
  get "transactions/index"
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Dashboard as the new home page
  root "dashboard#index"
  get "/dashboard", to: "dashboard#index"

  resources :bank_accounts
  resources :categories, only: [ :index, :new, :create ]
  resources :statement_files, only: %i[new create show]
  resources :transactions, only: %i[index update]
  resources :users, only: %i[new create]

  resource :session, only: %i[new create destroy]

  post "/statement_files/:id/reprocess", to: "statement_files#reprocess", as: :reprocess_statement_file
end
