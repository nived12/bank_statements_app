require "constraints/authenticated_constraint"
require "constraints/landing_domain_constraint"

Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # API Documentation - Swagger/OpenAPI (internal engines)
  mount Rswag::Ui::Engine => "/api/docs"
  mount Rswag::Api::Engine => "/api/docs"

  # API Documentation - Web interface (access controlled)
  get "/docs", to: "api_docs#index"

  # Landing page routes (vitt.io in production, any host in dev/test)
  constraints Constraints::LandingDomainConstraint.new do
    root "landing#index", as: :landing_root
    resources :waitlists, only: [:create]
  end

  # Legal static pages (public — no auth required)
  scope :legal do
    get :privacy,       to: "legal#privacy",       as: :legal_privacy
    get :terms,         to: "legal#terms",         as: :legal_terms
    get :financial_data, to: "legal#financial_data", as: :legal_financial_data
  end

  # Pricing page (public — no auth required)
  get "/pricing", to: "pricing#index", as: :pricing

  # Checkout success page — public, shown in mobile in-app browser after Stripe payment
  get "/checkout/success", to: "checkout#success", as: :checkout_success

  # Legal consent interstitial (session-authenticated users who haven't yet accepted)
  resource :legal_consent, only: %i[new create]

  # App routes (app.vitt.io in production, any host in dev/test)
  root "dashboard#index", constraints: Constraints::AuthenticatedConstraint.new
  root "sessions#new", as: :app_root
  get "/dashboard", to: "dashboard#index"

  resources :bank_accounts do
    resources :statement_files, only: [:index], controller: "bank_accounts/statement_files"
  end
  resources :categories
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
      post :reconcile_transfers
      get :check_transfer_candidates
      get :get_transfer_candidates
      post :process_transfer_candidates
      post :parse_voice
      post :parse_image
      get :recurring_suggestions
    end
  end
  resources :users, only: %i[new create]

  # Subscription upgrade page + Stripe checkout/portal (web — session auth)
  resource :subscription, only: [:show] do
    post :checkout
    get  :portal
  end

  # Profile edit (web — session auth; no password change, use forgot-password flow)
  resource :profile, only: [:show, :update]

  # Category rule lookup (merchant auto-suggest) + upsert (save rule on manual pick)
  resources :category_rules, except: [:show, :new] do
    collection do
      get :lookup
      post :upsert
    end
  end

  # Web PDF reports (session auth)
  get "reports/monthly", to: "reports#monthly", as: :monthly_report

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
      resource :user, only: [:show, :update], controller: "users" do
        patch :password, on: :member, action: :update_password
        patch :avatar,   on: :member, action: :update_avatar
      end

      # Password resets
      resources :password_resets, only: [:create, :update], param: :token

      # Email confirmations
      resources :email_confirmations, only: [:create, :update], param: :token

      # Transactions
      resources :transactions, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :summary
          post :parse_voice
          post :parse_image
          get :recurring_suggestions
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

      # Banks (public endpoint — no auth required)
      resources :banks, only: [:index]

      # Goals
      resources :goals, only: [:index, :show, :create, :update, :destroy]

      # Merchant Rules (smart categorization)
      resources :merchant_rules, only: [:index, :create, :destroy]

      # Devices (push notification registration)
      resources :devices, only: %i[create destroy], param: :push_token

      # User notification preferences
      resource :user_settings, only: %i[show update]

      # Reports
      get "reports/monthly", to: "reports#monthly"

      # Legal consent
      namespace :legal do
        post :accept
        get :status
      end

      # Statement Files
      resources :statement_files, only: [:index, :show, :create, :destroy] do
        member do
          post :retry
        end
      end

      # Subscription (Stripe checkout, portal, status)
      resource :subscription, only: [] do
        get  "/",         to: "subscriptions#status",   as: :status
        post "/checkout", to: "subscriptions#checkout", as: :checkout
        get  "/portal",   to: "subscriptions#portal",   as: :portal
      end
    end
  end

  # Error pages
  get "/404", to: "errors#not_found"
  get "/500", to: "errors#internal_server_error"
end
