Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # API Documentation - Swagger/OpenAPI (internal engines)
  mount Rswag::Ui::Engine => "/api/docs"
  mount Rswag::Api::Engine => "/api/docs"

  # API Documentation - Web interface (access controlled)
  get "/docs", to: "api_docs#index"

  # Dashboard as the new home page
  root "dashboard#index"
  get "/dashboard", to: "dashboard#index"

  resources :bank_accounts do
    resources :statement_files, only: [:index], controller: "bank_accounts/statement_files"
  end
  resources :categories
  resources :category_rules, except: [:show, :new]
  resources :statement_files, only: %i[index new create show destroy] do
    member do
      get :status
    end
  end
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
    resource :category, only: [:update], module: :transactions
    collection do
      get :export
      get :statement_files
      get :check_duplicates
      get :get_duplicates
      post :process_duplicates
    end
  end
  resources :users, only: %i[new create]

  resource :session, only: %i[new create destroy] do
    patch :update_timezone, on: :collection
  end

  # Password reset routes
  resources :password_resets, only: [:new, :create, :edit, :update], param: :token

  # Email confirmation routes
  resources :email_confirmations, only: [:show, :create], param: :token

  # OAuth routes
  get "/auth/:provider/callback", to: "sessions#oauth_callback"
  post "/auth/:provider/callback", to: "sessions#oauth_callback"
  get "/auth/failure", to: "sessions#oauth_failure"

  # API routes
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # Authentication endpoints
      post "/login", to: "authentication#login"
      post "/signup", to: "authentication#signup"
      post "/refresh", to: "authentication#refresh"
      delete "/logout", to: "authentication#logout"

      # Dashboard
      resource :dashboard, only: [:show], controller: "dashboard"

      # User profile
      resource :user, only: [:show, :update], controller: "users"

      # Password resets
      resources :password_resets, only: [:create, :update], param: :token

      # Email confirmations
      resources :email_confirmations, only: [:create, :update], param: :token

      # Transactions
      resources :transactions, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :summary
        end
      end

      # Categories
      resources :categories, only: [:index, :show, :create, :update, :destroy]

      # Bank Accounts
      resources :bank_accounts, only: [:index, :show, :create, :update, :destroy]

      # Savings
      resources :savings, only: [:index, :show, :create, :update, :destroy] do
        resources :saving_transactions, only: [:create, :destroy], path: "transactions"
      end

      # Debts
      resources :debts, only: [:index, :show, :create, :update, :destroy] do
        resources :debt_transactions, only: [:create, :destroy], path: "transactions"
      end

      # Statement Files
      resources :statement_files, only: [:index, :show, :create, :destroy] do
        member do
          post :retry
        end
      end
    end
  end

  # Error pages
  get "/404", to: "errors#not_found"
  get "/500", to: "errors#internal_server_error"
end
