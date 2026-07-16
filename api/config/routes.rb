# frozen_string_literal: true

Rails.application.routes.draw do
  if ENV["LAGO_SIDEKIQ_WEB"] == "true"
    mount Sidekiq::Web, at: "/sidekiq" if defined?(Sidekiq::Web)
    mount Sidekiq::Prometheus::Exporter, at: "/sidekiq/prometheus/metrics" if defined? Sidekiq::Prometheus::Exporter
  end
  mount Karafka::Web::App, at: "/karafka" if ENV["LAGO_KARAFKA_WEB"]
  mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql" if Rails.env.development?
  mount Yabeda::Prometheus::Exporter, at: "/metrics"
  mount ActionCable.server, at: "/cable"

  post "/graphql", to: "graphql#execute"

  # Health Check status
  get "/health", to: "application#health"
  get "/ready", to: "application#ready"

  namespace :data_api do
    namespace :v1 do
      resources :charges, only: [] do
        post :forecasted_usage_amount, on: :member
        post :bulk_forecasted_usage_amount, on: :collection
      end
    end
  end

  namespace :api do
    namespace :v1 do
      resources :activity_logs, param: :activity_id, only: %i[index show]
      resources :api_logs, param: :request_id, only: %i[index show]
      resources :security_logs, param: :log_id, only: %i[index show]

      namespace :analytics do
        get :gross_revenue, to: "gross_revenues#index", as: :gross_revenue
        get :invoiced_usage, to: "invoiced_usages#index", as: :invoiced_usage
        get :invoice_collection, to: "invoice_collections#index", as: :invoice_collection
        get :mrr, to: "mrrs#index", as: :mrr
        get :overdue_balance, to: "overdue_balances#index", as: :overdue_balance
      end

      get "analytics/usage", to: "data_api/usages#index", as: :usage

      resources :billing_entities, param: :code, only: %i[index show update create]

      resources :customers, param: :external_id, only: %i[create index show destroy] do
        get :portal_url

        get :current_usage, to: "customers/usage#current"
        get :projected_usage, to: "customers/projected_usage#current"
        get :past_usage, to: "customers/usage#past"

        post :checkout_url

        scope module: :customers do
          resources :applied_coupons, only: %i[index destroy]
          resources :credit_notes, only: %i[index]
          resources :invoices, only: %i[index]
          resources :payments, only: %i[index]
          resources :payment_requests, only: %i[index]
          resources :subscriptions, only: %i[index]
          resources :wallets, only: %i[create update show index], param: :code do
            scope module: :wallets do
              resources :alerts, only: %i[create index update show destroy], param: :code do
                collection do
                  delete "/", action: :destroy_all
                end
              end
              resource :metadata, only: %i[create update destroy] do
                delete ":key", action: :destroy_key, on: :member
              end
            end
          end
          delete "/wallets/:code", to: "wallets#terminate"
          resources :payment_methods, only: %i[index destroy] do
            put :set_as_default, on: :member
          end
        end
      end

      resources :subscriptions, only: %i[create update show index], param: :external_id do
        resource :lifetime_usage, only: %i[show update], controller: "subscriptions/lifetime_usages"
        resources :alerts, only: %i[create index update show destroy], param: :code, controller: "subscriptions/alerts" do
          collection do
            delete "/", action: :destroy_all
          end
        end
        resources :entitlements, only: %i[index destroy], param: :code, code: /.*/, controller: "subscriptions/entitlements" do
          resources :privileges, only: %i[destroy], param: :code, code: /.*/, controller: "subscriptions/entitlements/privileges"
        end
        patch :entitlements, to: "subscriptions/entitlements#update"
        resources :fixed_charges, only: %i[index show update], param: :code, code: /.*/, controller: "subscriptions/fixed_charges"
        resources :charges, only: %i[index show update], param: :code, code: /.*/, controller: "subscriptions/charges" do
          resources :filters, only: %i[index show create update destroy], controller: "subscriptions/charges/filters"
        end
      end
      delete "/subscriptions/:external_id", to: "subscriptions#terminate", as: :terminate

      resources :add_ons, param: :code, code: /.*/
      resources :billable_metrics, param: :code, code: /.*/ do
        post :evaluate_expression, on: :collection
      end

      resources :features, param: :code, code: /.*/, only: %i[index show create update destroy] do
        scope module: :features do
          resources :privileges, only: %i[destroy], param: :code
        end
      end

      resources :coupons, param: :code, code: /.*/
      resources :credit_notes, only: %i[create update show index] do
        post :download, on: :member, action: :download_pdf
        post :download_pdf, on: :member
        post :download_xml, on: :member
        post :resend_email, on: :member
        put :void, on: :member
        post :estimate, on: :collection
        scope module: :credit_notes do
          resource :metadata, only: %i[create update destroy] do
            delete ":key", action: :destroy_key, on: :member
          end
        end
      end
      get :events_enriched, to: "events#index_enriched"
      resources :events, only: %i[create show index], constraints: {id: /[^\/]+/} do
        post :estimate_fees, on: :collection
        post :estimate_instant_fees, on: :collection
        post :batch_estimate_instant_fees, on: :collection
      end
      resources :applied_coupons, only: %i[create index]
      resources :fees, only: %i[show update index destroy]
      resources :invoices, only: %i[create update show index] do
        post :download, on: :member, action: :download_pdf
        post :download_pdf, on: :member
        post :download_xml, on: :member
        post :resend_email, on: :member
        post :void, on: :member
        post :lose_dispute, on: :member
        post :retry, on: :member
        post :retry_payment, on: :member
        post :payment_url, on: :member
        post :preview, on: :collection
        put :refresh, on: :member
        put :finalize, on: :member
        put :sync_salesforce_id, on: :member
      end
      resources :payment_receipts, only: %i[index show] do
        post :resend_email, on: :member
      end
      resources :payment_requests, only: %i[create index show]
      resources :order_forms, only: %i[show index] do
        post :mark_as_signed, on: :member
        post :void, on: :member
      end

      resources :quotes, only: %i[index show] do
        resources :versions, only: %i[index], controller: "quotes/versions"
      end
      resources :quote_versions, only: %i[show] do
        post :approve, on: :member
        post :void, on: :member
        post :clone, on: :member
      end

      resources :orders, only: %i[show index]
      resources :payments, only: %i[create index show]
      resources :plans, param: :code, code: /.*/ do
        resources :charges, only: %i[index show create update destroy], param: :code, code: /.*/, controller: "plans/charges" do
          resources :filters, only: %i[index show create update destroy], controller: "plans/charges/filters"
        end
        resources :fixed_charges, only: %i[index show create update destroy], param: :code, code: /.*/, controller: "plans/fixed_charges"
        resources :entitlements, only: %i[index show create destroy], param: :code, code: /.*/, controller: "plans/entitlements" do
          resources :privileges, only: %i[destroy], param: :code, code: /.*/, controller: "plans/entitlements/privileges"
        end
        patch :entitlements, to: "plans/entitlements#update"
        scope module: :plans do
          resource :metadata, only: %i[create update destroy] do
            delete ":key", action: :destroy_key, on: :member
          end
        end
      end
      resources :taxes, param: :code, code: /.*/
      resources :wallet_transactions, only: %i[create show] do
        post :payment_url, on: :member
        get :consumptions, on: :member
        get :fundings, on: :member
      end
      get "/wallets/:id/wallet_transactions", to: "wallet_transactions#index"
      resources :wallets, only: %i[create update show index] do
        scope module: :wallets do
          resource :metadata, only: %i[create update destroy] do
            delete ":key", action: :destroy_key, on: :member
          end
        end
      end
      delete "/wallets/:id", to: "wallets#terminate"
      post "/events/batch", to: "events#batch"

      get "/organizations", to: "organizations#show"
      put "/organizations", to: "organizations#update"
      get "/organizations/grpc_token", to: "organizations#grpc_token"

      resources :webhook_endpoints, only: %i[create index show destroy update]
      resources :webhooks, only: %i[] do
        get :public_key, on: :collection
        get :json_public_key, on: :collection
      end
    end
  end
  resources :webhooks, only: [] do
    post "stripe/:organization_id", to: "webhooks#stripe", on: :collection, as: :stripe

    post "cashfree/:organization_id", to: "webhooks#cashfree", on: :collection, as: :cashfree
    post "flutterwave/:organization_id", to: "webhooks#flutterwave", on: :collection, as: :flutterwave
    post "gocardless/:organization_id", to: "webhooks#gocardless", on: :collection, as: :gocardless
    post "adyen/:organization_id", to: "webhooks#adyen", on: :collection, as: :adyen
    post "moneyhash/:organization_id", to: "webhooks#moneyhash", on: :collection, as: :moneyhash
  end

  namespace :admin do
    resources :memberships, only: %i[create]
    resources :organizations, only: %i[update create]
    resources :invoices do
      post :regenerate, on: :member
    end
  end

  if Rails.env.development?
    namespace :dev_tools do
      get "/invoices/:id", to: "invoices#show"
      get "/payment_receipts/:id", to: "payment_receipts#show"
    end
  end

  match "*unmatched" => "application#not_found",
    :via => %i[get post put delete patch],
    :constraints => lambda { |req|
      req.path.exclude?("rails/active_storage")
    }
end
