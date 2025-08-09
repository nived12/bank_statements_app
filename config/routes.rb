Rails.application.routes.draw do
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  resources :statement_files, only: %i[new create show]
  resources :bank_accounts, only: %i[new create index]
  root "statement_files#new"
end
