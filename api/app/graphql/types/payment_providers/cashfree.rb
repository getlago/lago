# frozen_string_literal: true

module Types
  module PaymentProviders
    class Cashfree < Types::BaseObject
      graphql_name "CashfreeProvider"

      field :code, String, null: false
      field :id, ID, null: false
      field :name, String, null: false

      field :client_id, String, null: true, permission: "organization:integrations:view"
      field :client_secret, String, null: true, permission: "organization:integrations:view"
      field :success_redirect_url, String, null: true, permission: "organization:integrations:view"
    end
  end
end
