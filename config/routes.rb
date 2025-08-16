Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Dashboard as the new home page
    root "dashboard#index"
    get "/dashboard", to: "dashboard#index"

    resources :bank_accounts
    resources :categories
    resources :statement_files, only: %i[new create show]
    resources :transactions, only: %i[index update]
    resources :users, only: %i[new create]

    resource :session, only: %i[new create destroy] do
      post :heartbeat, on: :collection
    end
  end
end
