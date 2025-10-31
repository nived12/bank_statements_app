Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Dashboard as the new home page
  root "dashboard#index"
  get "/dashboard", to: "dashboard#index"

  resources :bank_accounts do
    resources :statement_files, only: [:index], controller: "bank_accounts/statement_files"
  end
  resources :categories
  resources :statement_files, only: %i[index new create show destroy]
  post "/statement_files/:id/retry", to: "statement_files#retry", as: :retry_statement_file

  # Goals
  resources :goals

  # Savings and Debts
  resources :savings do
    resources :saving_transactions, only: [:create, :destroy], path: "transactions"
  end

  resources :debts do
    resources :debt_transactions, only: [:create, :destroy], path: "transactions"
  end

  resources :transactions do
    collection do
      get :statement_files
      get :check_duplicates
      get :get_duplicates
      post :process_duplicates
    end
  end
  resources :users, only: %i[new create]

  resource :session, only: %i[new create destroy] do
    post :heartbeat, on: :collection
    patch :update_timezone, on: :collection
  end

  # OAuth routes
  get "/auth/:provider/callback", to: "sessions#oauth_callback"
  post "/auth/:provider/callback", to: "sessions#oauth_callback"
  get "/auth/failure", to: "sessions#oauth_failure"

  # Error pages
  get "/404", to: "errors#not_found"
  get "/500", to: "errors#internal_server_error"
end
