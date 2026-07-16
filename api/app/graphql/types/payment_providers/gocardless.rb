# frozen_string_literal: true

module Types
  module PaymentProviders
    class Gocardless < Types::BaseObject
      graphql_name "GocardlessProvider"

      field :code, String, null: false
      field :id, ID, null: false
      field :name, String, null: false

      field :has_access_token, Boolean, null: false, permission: "organization:integrations:view"
      field :success_redirect_url, String, null: true, permission: "organization:integrations:view"
      field :webhook_secret, String, null: true, permission: "organization:integrations:view"

      # NOTE: Access token is a sensitive information. It should not be sent back to the
      #       front end application
      def has_access_token
        object.access_token.present?
      end
    end
  end
end
