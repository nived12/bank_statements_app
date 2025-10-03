Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Dashboard as the new home page
    root "dashboard#index"
    get "/dashboard", to: "dashboard#index"

    resources :bank_accounts
    resources :categories
      resources :statement_files, only: %i[index new create show destroy] do
    member do
      post :retry
    end
  end
    resources :transactions, only: %i[index create update destroy] do
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
  end

  # OAuth routes (outside locale scope)
  get "/auth/:provider/callback", to: "sessions#oauth_callback"
  post "/auth/:provider/callback", to: "sessions#oauth_callback"
  get "/auth/failure", to: "sessions#oauth_failure"

  # Error pages (outside locale scope)
  get "/404", to: "errors#not_found"
  get "/500", to: "errors#internal_server_error"
end
