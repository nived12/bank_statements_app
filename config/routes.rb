Rails.application.routes.draw do
  get "transactions/index"
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  resources :bank_accounts, only: %i[new create index]
  resources :statement_files, only: %i[new create show]
  resources :transactions, only: %i[index]

  root "statement_files#new"
end
